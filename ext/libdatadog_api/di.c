#include <stdbool.h>

#include "datadog_ruby_common.h"

// Prototypes for Ruby functions declared in internal Ruby headers.
// rb_iseqw_new wraps an internal iseq pointer into a Ruby-visible
// RubyVM::InstructionSequence object.
VALUE rb_iseqw_new(const void *iseq);
// rb_iseqw_to_iseq unwraps a RubyVM::InstructionSequence object back
// to its internal iseq pointer.
const void *rb_iseqw_to_iseq(VALUE iseqw);
int rb_objspace_internal_object_p(VALUE obj);
void rb_objspace_each_objects(
    int (*callback)(void *start, void *end, size_t stride, void *data),
    void *data);

#define IMEMO_TYPE_ISEQ 7

// The ID value of the string "mesg" which is used in Ruby source as
// id_mesg or idMesg, and is used to set and retrieve the exception message
// from standard library exception classes like NameError.
static ID id_mesg;

// ID for the fiber-local key that backs the method-probe re-entrancy guard.
// Storage is the same hashtable that backs Thread#[] / Thread#[]=, but accessed
// directly via rb_thread_local_aref / rb_thread_local_aset so that user-installed
// method probes on Thread#[] / Thread#[]= cannot intercept guard reads/writes.
static ID id_datadog_di_in_probe;

// IDs for the C method-probe wrapper: ivar holding per-probe state on the
// prepended module, and the Ruby helper methods the wrapper invokes for
// pre-super and post-super work.
static ID id_di_method_probe_state;
static ID id_run_method_probe_pre;
static ID id_run_method_probe_post;

// Returns whether the argument is an IMEMO of type ISEQ.
static bool ddtrace_imemo_iseq_p(VALUE v) {
  return rb_objspace_internal_object_p(v) && RB_TYPE_P(v, T_IMEMO) && ddtrace_imemo_type(v) == IMEMO_TYPE_ISEQ;
}

static int ddtrace_di_os_obj_of_i(void *vstart, void *vend, size_t stride, void *data)
{
  VALUE *array = (VALUE *)data;

  VALUE v = (VALUE)vstart;
  for (; v != (VALUE)vend; v += stride) {
    if (ddtrace_imemo_iseq_p(v)) {
      VALUE iseq = rb_iseqw_new((void *) v);
      rb_ary_push(*array, iseq);
    }
  }

  return 0;
}

/*
Returns all RubyVM::InstructionSequence objects existing in the current process.

This uses the same approach as ruby/debug's iseq_collector.c:
https://github.com/ruby/debug/blob/master/ext/debug/iseq_collector.c
*/
static VALUE all_iseqs(DDTRACE_UNUSED VALUE _self) {
  VALUE array = rb_ary_new();
  rb_objspace_each_objects(ddtrace_di_os_obj_of_i, &array);
  return array;
}

/*
 * call-seq:
 *   DI.exception_message(exception) -> String | Object
 *
 * Returns the exception message associated with the exception via the
 * exception's constructor.
 *
 * This method does not invoke Ruby code and as such will not call
 * the +message+ method, if one is defined on the exception object.
 *
 * Normally, the exception message is a string, however there is no
 * type enforcement done by Ruby for the messages and objects of arbitrary
 * classes can be passed to exception constructors and will, subsequently,
 * be returned by this method.
 *
 * @param exception [Exception] The exception object
 * @return [String | Object] The exception message
 */
static VALUE exception_message(DDTRACE_UNUSED VALUE _self, VALUE exception) {
  return rb_ivar_get(exception, id_mesg);
}

/*
 * call-seq:
 *   DI.in_probe? -> true | false
 *
 * Returns whether the current fiber is currently inside DI probe processing.
 * Reads the same fiber-local storage as Thread.current[:datadog_di_in_probe]
 * but bypasses Thread#[] method dispatch — a user method probe on Thread#[]
 * cannot observe or intercept this call.
 *
 * @api private
 */
static VALUE in_probe_p(DDTRACE_UNUSED VALUE _self) {
  VALUE v = rb_thread_local_aref(rb_thread_current(), id_datadog_di_in_probe);
  return RTEST(v) ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   DI.enter_probe -> nil
 *
 * Marks the current fiber as inside DI probe processing. Writes to the same
 * fiber-local storage as Thread.current[:datadog_di_in_probe] = true, but
 * bypasses Thread#[]= method dispatch — a user method probe on Thread#[]=
 * cannot observe or intercept this call.
 *
 * @api private
 */
static VALUE enter_probe(DDTRACE_UNUSED VALUE _self) {
  rb_thread_local_aset(rb_thread_current(), id_datadog_di_in_probe, Qtrue);
  return Qnil;
}

/*
 * call-seq:
 *   DI.leave_probe -> nil
 *
 * Marks the current fiber as no longer inside DI probe processing. Writes to
 * the same fiber-local storage as Thread.current[:datadog_di_in_probe] = nil,
 * but bypasses Thread#[]= method dispatch — a user method probe on Thread#[]=
 * cannot observe or intercept this call.
 *
 * @api private
 */
static VALUE leave_probe(DDTRACE_UNUSED VALUE _self) {
  rb_thread_local_aset(rb_thread_current(), id_datadog_di_in_probe, Qnil);
  return Qnil;
}

/*
 * call-seq:
 *   DI.array_empty?(arr) -> true | false
 *
 * Returns whether the given Array is empty by direct length access via
 * RARRAY_LEN, bypassing Array#empty? method dispatch. Used in the method
 * probe wrapper to test args/kwargs shape without giving user-installed
 * method probes on Array#empty? a chance to recurse.
 *
 * Raises TypeError if the argument is not an Array — RARRAY_LEN reads
 * struct fields directly and would return garbage for any other type.
 *
 * @api private
 */
static VALUE array_empty_p(DDTRACE_UNUSED VALUE _self, VALUE obj) {
  Check_Type(obj, T_ARRAY);
  return RARRAY_LEN(obj) == 0 ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   DI.hash_empty?(h) -> true | false
 *
 * Returns whether the given Hash is empty by direct size access via
 * RHASH_SIZE, bypassing Hash#empty? method dispatch. Used in the method
 * probe wrapper to test args/kwargs shape without giving user-installed
 * method probes on Hash#empty? a chance to recurse.
 *
 * Raises TypeError if the argument is not a Hash — RHASH_SIZE reads
 * struct fields directly and would return garbage for any other type.
 *
 * @api private
 */
static VALUE hash_empty_p(DDTRACE_UNUSED VALUE _self, VALUE obj) {
  Check_Type(obj, T_HASH);
  return RHASH_SIZE(obj) == 0 ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   DI.invoke_proc(proc, *args) -> Object
 *
 * Invokes a Proc with the given positional arguments, bypassing Proc#call
 * method dispatch. Used in the method probe wrapper to call the do_super
 * lambda (and other internal lambdas) without giving user-installed method
 * probes on Proc#call a chance to recurse.
 *
 * Implemented via rb_proc_call_with_block, which invokes the Proc's
 * underlying block directly without going through Ruby method lookup. A user
 * probe on Proc#call is therefore not intercepted, even if the Proc passed
 * here is itself a lambda (and thus a Proc instance).
 *
 * Raises TypeError if the first argument is not a Proc.
 *
 * @api private
 */
static VALUE invoke_proc(int argc, VALUE *argv, DDTRACE_UNUSED VALUE _self) {
  if (argc < 1) {
    rb_raise(rb_eArgError, "wrong number of arguments (given 0, expected 1+)");
  }
  VALUE proc = argv[0];
  if (!rb_obj_is_proc(proc)) {
    rb_raise(rb_eTypeError, "wrong argument type (expected Proc)");
  }
  return rb_proc_call_with_block(proc, argc - 1, argv + 1, Qnil);
}

// Inline helpers for the re-entrancy guard. The Ruby-callable
// DI.in_probe? / DI.enter_probe / DI.leave_probe methods are still
// defined and used elsewhere; these inline versions are for the C wrapper
// to avoid Ruby method dispatch on the hot path.
static inline int in_probe_inline_p(void) {
  return RTEST(rb_thread_local_aref(rb_thread_current(), id_datadog_di_in_probe));
}

static inline void leave_probe_inline(void) {
  rb_thread_local_aset(rb_thread_current(), id_datadog_di_in_probe, Qnil);
}

// Walks `receiver_class`'s ancestors looking for a module whose
// @__di_method_probe_state ivar is an Array whose last element (the
// method-name symbol) matches `method_id`. Returns the state Array,
// or Qnil if no matching module is found.
//
// The walk is O(depth) per call. A class with multiple probed methods
// has one prepended module per method (#hook_method creates a fresh
// Module per hook), so the typical depth is small — the prepended
// module for the called method sits near the front of the ancestors.
static VALUE find_method_probe_state(VALUE receiver_class, ID method_id) {
  VALUE ancestors = rb_mod_ancestors(receiver_class);
  long n = RARRAY_LEN(ancestors);
  for (long i = 0; i < n; i++) {
    VALUE m = RARRAY_AREF(ancestors, i);
    if (RB_TYPE_P(m, T_MODULE)) {
      VALUE state = rb_ivar_get(m, id_di_method_probe_state);
      if (RB_TYPE_P(state, T_ARRAY) && RARRAY_LEN(state) == 5) {
        VALUE name = RARRAY_AREF(state, 4);
        if (RB_TYPE_P(name, T_SYMBOL) && SYM2ID(name) == method_id) {
          return state;
        }
      }
    }
  }
  return Qnil;
}

// Wrapper for rb_protect: invokes rb_call_super with the captured argc/argv.
struct super_call_data {
  int argc;
  const VALUE *argv;
};

static VALUE call_super_protected(VALUE data) {
  struct super_call_data *s = (struct super_call_data *)data;
  return rb_call_super(s->argc, s->argv);
}

// The C-implemented method probe wrapper. Replaces the Ruby
// define_method block that #hook_method previously installed on the
// prepended module.
//
// Invariants matched from the Ruby form:
//   - Re-entrancy guard fast path: if DI.in_probe? is set, just super.
//   - Un-guarded path: invoke Ruby pre-helper (which calls enter_probe
//     and may set up snapshot state), then rb_call_super, then Ruby
//     post-helper. leave_probe is called unconditionally on the way out
//     (idempotent).
//   - Exceptions from super are captured and re-raised after the post
//     helper runs, so the responder callback still fires.
static VALUE method_probe_wrapper_c(int argc, VALUE *argv, VALUE self) {
  // Fast path: re-entrancy guard set — just super, no DI work.
  if (in_probe_inline_p()) {
    return rb_call_super(argc, argv);
  }

  ID method_id = rb_frame_this_func();
  VALUE state = find_method_probe_state(rb_class_of(self), method_id);
  if (NIL_P(state)) {
    // Wrapper installed without matching state — shouldn't happen.
    // Pass through rather than crash.
    return rb_call_super(argc, argv);
  }

  VALUE instrumenter = RARRAY_AREF(state, 0);
  VALUE probe = RARRAY_AREF(state, 1);
  VALUE responder = RARRAY_AREF(state, 2);
  VALUE loc = RARRAY_AREF(state, 3);
  VALUE method_name_sym = RARRAY_AREF(state, 4);

  // Split positional args and kwargs. rb_scan_args with "*:" peels off
  // a symbol-keyed hash from the end of argv when present.
  VALUE args = Qnil;
  VALUE kwargs = Qnil;
  rb_scan_args(argc, argv, "*:", &args, &kwargs);
  if (NIL_P(kwargs)) {
    kwargs = rb_hash_new();
  }

  // Materialize the block argument as a Proc if one was given. The Ruby
  // helpers need this for snapshot capture and to forward to user code.
  // The block is also automatically forwarded by rb_call_super for the
  // original method invocation, so we don't need to pass it there.
  VALUE target_block = rb_block_given_p() ? rb_block_proc() : Qnil;

  // Pre-super: invoke Ruby helper that handles enabled-check,
  // enter_probe, condition evaluation, rate-limiter, serialize_args.
  // Returns nil (disabled, no enter_probe done), :skip (rate-limited /
  // condition-failed, enter_probe and leave_probe already done), or a
  // Hash (firing, enter_probe and leave_probe done, post will re-enter).
  VALUE pre_argv[8] = {
    args, kwargs, target_block, self,
    probe, responder, loc, method_name_sym,
  };
  VALUE pre_state = rb_funcallv(instrumenter, id_run_method_probe_pre,
                                8, pre_argv);

  // Invoke original method via super, capturing any exception.
  struct super_call_data sd = { argc, argv };
  int prot_state = 0;
  VALUE rv = rb_protect(call_super_protected, (VALUE)&sd, &prot_state);
  VALUE exc = Qnil;
  if (prot_state) {
    exc = rb_errinfo();
    rb_set_errinfo(Qnil);
    rv = Qnil;
  }

  // Post-super: invoke Ruby helper that builds snapshot Context and
  // invokes responder callback. No-op when pre_state is nil/:skip.
  VALUE post_argv[3] = { pre_state, rv, exc };
  rb_funcallv(instrumenter, id_run_method_probe_post, 3, post_argv);

  // Release re-entrancy guard. enter_probe was set only for the pre_state
  // = Hash case (and the post helper re-enters before building the
  // snapshot); on the nil/:skip paths leave_probe is a no-op. Calling
  // unconditionally keeps the cleanup simple and is idempotent.
  leave_probe_inline();

  if (!NIL_P(exc)) {
    rb_exc_raise(exc);
  }
  return rv;
}

/*
 * call-seq:
 *   DI.install_method_probe_wrapper(mod, method_name, instrumenter, probe, responder, loc) -> nil
 *
 * Installs the C-implemented method probe wrapper on the given module as
 * an instance method named method_name (a Symbol). The wrapper handles
 * the re-entrancy guard fast path inline and, on the un-guarded path,
 * delegates to Ruby helpers for snapshot building while calling
 * rb_call_super directly for the original method invocation.
 *
 * Per-probe state (instrumenter, probe, responder, loc, method_name) is
 * stored as a frozen Array in @__di_method_probe_state on the module.
 * When the wrapper is invoked, it looks up its state by walking the
 * receiver's class's ancestors.
 *
 * @api private
 */
static VALUE install_method_probe_wrapper(DDTRACE_UNUSED VALUE _self,
                                          VALUE mod,
                                          VALUE method_name_sym,
                                          VALUE instrumenter,
                                          VALUE probe,
                                          VALUE responder,
                                          VALUE loc) {
  Check_Type(mod, T_MODULE);
  Check_Type(method_name_sym, T_SYMBOL);

  VALUE state = rb_ary_new_from_args(5, instrumenter, probe, responder,
                                     loc, method_name_sym);
  rb_ary_freeze(state);
  rb_ivar_set(mod, id_di_method_probe_state, state);

  rb_define_method_id(mod, SYM2ID(method_name_sym),
                      method_probe_wrapper_c, -1);
  return Qnil;
}

// rb_iseq_type was added in Ruby 3.1 (commit 89a02d89 by Koichi Sasada,
// 2021-12-19). It returns the iseq type as a Symbol. On Ruby < 3.1 this
// function does not exist, so have_func('rb_iseq_type') in extconf.rb
// gates compilation. When unavailable, backfill_registry falls back to
// the first_lineno == 0 heuristic.
#ifdef HAVE_RB_ISEQ_TYPE
VALUE rb_iseq_type(const void *iseq);

/*
 * call-seq:
 *   DI.iseq_type(iseq) -> Symbol
 *
 * Returns the type of an InstructionSequence as a symbol by calling
 * the internal rb_iseq_type() function (available since Ruby 3.1).
 *
 * This method is only defined when rb_iseq_type is detected at compile
 * time via have_func in extconf.rb. On Ruby < 3.1 it is not available
 * and callers must use an alternative (e.g. first_lineno heuristic).
 *
 * Possible return values: :top, :method, :block, :class, :rescue,
 * :ensure, :eval, :main, :plain.
 *
 * :top and :main represent whole-file iseqs (from require/load and the
 * entry point script respectively). Other types represent sub-file
 * constructs (method definitions, class bodies, blocks, etc.).
 *
 * Used by CodeTracker#backfill_registry to distinguish whole-file iseqs
 * from per-method/block/class iseqs when populating the registry from
 * the object space.
 *
 * @param iseq [RubyVM::InstructionSequence] The instruction sequence
 * @return [Symbol] The iseq type
 */
static VALUE iseq_type(DDTRACE_UNUSED VALUE _self, VALUE iseq_val) {
  const void *iseq = rb_iseqw_to_iseq(iseq_val);
  if (!iseq) return Qnil;
  return rb_iseq_type(iseq);
}
#endif

void di_init(VALUE datadog_module) {
  id_mesg = rb_intern("mesg");
  id_datadog_di_in_probe = rb_intern("datadog_di_in_probe");
  id_di_method_probe_state = rb_intern("@__di_method_probe_state");
  id_run_method_probe_pre = rb_intern("run_method_probe_pre");
  id_run_method_probe_post = rb_intern("run_method_probe_post");

  VALUE di_module = rb_define_module_under(datadog_module, "DI");
  rb_define_singleton_method(di_module, "all_iseqs", all_iseqs, 0);
  rb_define_singleton_method(di_module, "exception_message", exception_message, 1);
  rb_define_singleton_method(di_module, "in_probe?", in_probe_p, 0);
  rb_define_singleton_method(di_module, "enter_probe", enter_probe, 0);
  rb_define_singleton_method(di_module, "leave_probe", leave_probe, 0);
  rb_define_singleton_method(di_module, "array_empty?", array_empty_p, 1);
  rb_define_singleton_method(di_module, "hash_empty?", hash_empty_p, 1);
  rb_define_singleton_method(di_module, "invoke_proc", invoke_proc, -1);
  rb_define_singleton_method(di_module, "install_method_probe_wrapper",
                             install_method_probe_wrapper, 6);
#ifdef HAVE_RB_ISEQ_TYPE
  rb_define_singleton_method(di_module, "iseq_type", iseq_type, 1);
#endif
}
