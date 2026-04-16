"""Audit decorator stub for alive-mcp tool handlers (T6 scaffolding).

Every MCP tool handler in alive-mcp is wrapped with :func:`audited` at the
decorator layer. The v0.1 stub is a pure pass-through -- it preserves the
wrapped function's signature via :func:`functools.wraps` and forwards all
arguments and the return value unchanged. T12 replaces the body with the
real audit writer, which will:

1. Resolve the :class:`~alive_mcp.server.AppContext` out of the FastMCP
   :class:`~mcp.server.fastmcp.Context` (threaded via ``ctx`` in every
   tool handler).
2. Build an audit record: tool name, hashed/length-summarized arg values,
   start timestamp, and a ``finished`` hook that fires on return or
   exception with duration_ms and error_code.
3. Push onto :attr:`AppContext.audit_queue`; the background writer task
   (also stubbed in T5, replaced in T12) drains into JSONL.

The decorator API is intentionally the subset T12 needs:

* ``@audited`` with no args -- applied as ``@audited`` or ``@audited()``.
* Optional keyword ``tool_name="foo"`` to override the wrapped function's
  ``__name__`` (useful when handler functions are named ``_list_walnuts``
  internally but exposed as ``list_walnuts`` on the wire).

Anything T12 needs beyond that (category tags, per-tool redaction rules,
opt-in verbatim walnut paths per ``ALIVE_MCP_AUDIT_PUBLIC_WALNUT_PATHS``)
is layered on top of this stable signature, not swapped underneath it.

Forward-compat contract
-----------------------

The decorator MUST continue to:

* Accept both ``@audited`` and ``@audited(tool_name=...)`` forms.
* Preserve the wrapped function's ``__name__``, ``__doc__``,
  ``__module__``, and signature via :func:`functools.wraps`.
* Be safe to apply to both sync and async callables.
* Never raise synchronously -- if the audit machinery itself fails, the
  tool call still executes. (T12 enforces this via a try/except around
  queue puts; the stub trivially satisfies it by doing nothing.)

Tests in ``tests/test_tools_walnut.py`` assert each of these properties
so a T12 replacement that regresses any of them fails loudly.
"""
from __future__ import annotations

import asyncio
import functools
from typing import Any, Callable, Optional, TypeVar, Union, overload

# Generic callable -- the decorator preserves whatever shape the target
# function has. We use ``Any`` for the return type rather than a narrower
# TypeVar because the wrapped function's return is opaque to the stub.
F = TypeVar("F", bound=Callable[..., Any])


@overload
def audited(func: F) -> F: ...


@overload
def audited(
    *, tool_name: Optional[str] = ...
) -> Callable[[F], F]: ...


def audited(
    func: Optional[F] = None,
    *,
    tool_name: Optional[str] = None,
) -> Union[F, Callable[[F], F]]:
    """Wrap a tool handler in the (stub) audit decorator.

    Usage:

    .. code-block:: python

        @audited
        async def list_walnuts(ctx, limit=50, cursor=None):
            ...

        @audited(tool_name="list_walnuts")
        async def _list_walnuts_impl(ctx, limit=50, cursor=None):
            ...

    In v0.1 the decorator is a no-op pass-through. It exists so tool code
    can commit to the final shape today without a rewrite when T12 wires
    the JSONL writer. Both sync and async wrapped functions are
    supported; :func:`asyncio.iscoroutinefunction` picks the right
    wrapper shape.

    Parameters
    ----------
    func:
        The target when used as a bare ``@audited``. Internal -- callers
        typically don't pass this explicitly.
    tool_name:
        Override for the name recorded in the audit record. Defaults to
        the wrapped function's ``__name__``. Stored on the wrapper as
        ``__alive_tool_name__`` so T12 can read it without re-deriving.
    """

    def _decorate(target: F) -> F:
        recorded_name = tool_name if tool_name is not None else target.__name__

        if asyncio.iscoroutinefunction(target):
            @functools.wraps(target)
            async def _async_wrapper(*args: Any, **kwargs: Any) -> Any:
                # T12: emit start record here; on return or raise, emit
                # a finish record with duration_ms. For v0.1 we just
                # forward -- the envelope layer already guarantees tools
                # never raise, so the audit record shape stays stable
                # when this becomes real.
                return await target(*args, **kwargs)

            # Stash the tool-name override where T12 can find it without
            # parsing the signature again. Harmless when the name matches
            # ``target.__name__``.
            _async_wrapper.__alive_tool_name__ = recorded_name  # type: ignore[attr-defined]
            return _async_wrapper  # type: ignore[return-value]

        @functools.wraps(target)
        def _sync_wrapper(*args: Any, **kwargs: Any) -> Any:
            return target(*args, **kwargs)

        _sync_wrapper.__alive_tool_name__ = recorded_name  # type: ignore[attr-defined]
        return _sync_wrapper  # type: ignore[return-value]

    # Bare ``@audited`` form -- caller passed the function directly.
    if func is not None:
        return _decorate(func)
    # ``@audited(tool_name=...)`` form -- return the decorator factory.
    return _decorate


__all__ = ["audited"]
