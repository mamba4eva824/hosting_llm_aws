"""FastAPI layer in front of Ollama (same container: Ollama listens on 11434)."""

from __future__ import annotations

import os

import httpx
from fastapi import FastAPI, Request, Response

OLLAMA_BASE = os.environ.get("OLLAMA_BASE_URL", "http://127.0.0.1:11434")

app = FastAPI(
    title="Inference API",
    description="Proxies to Ollama; use port 5000 as your API boundary instead of 11434.",
    version="0.1.0",
    docs_url="/docs",
    redoc_url=None,
)


@app.get("/health")
async def health() -> dict[str, str]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        r = await client.get(f"{OLLAMA_BASE}/")
    if r.status_code != 200:
        return {"status": "degraded", "ollama": f"http {r.status_code}"}
    return {"status": "ok", "ollama": "running"}


async def _proxy_to_ollama(request: Request, upstream_path: str) -> Response:
    url = f"{OLLAMA_BASE}{upstream_path}"
    if request.query_params:
        url = f"{url}?{request.query_params}"

    body = await request.body()
    headers = {
        k: v
        for k, v in request.headers.items()
        if k.lower() in ("content-type", "accept", "authorization")
    }

    timeout = httpx.Timeout(600.0, connect=30.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        try:
            r = await client.request(
                request.method,
                url,
                content=body if body else None,
                headers=headers,
            )
        except httpx.RequestError as e:
            return Response(
                content=f'{{"error":"upstream: {e!s}"}}',
                status_code=502,
                media_type="application/json",
            )

    out_headers = {
        k: v
        for k, v in r.headers.items()
        if k.lower() in ("content-type", "content-length")
    }
    return Response(content=r.content, status_code=r.status_code, headers=out_headers)


@app.get("/")
async def ollama_root(request: Request) -> Response:
    return await _proxy_to_ollama(request, "/")


@app.api_route(
    "/v1/{path:path}",
    methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
)
async def proxy_v1(path: str, request: Request) -> Response:
    return await _proxy_to_ollama(request, f"/v1/{path}")


@app.api_route(
    "/api/{path:path}",
    methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
)
async def proxy_api(path: str, request: Request) -> Response:
    return await _proxy_to_ollama(request, f"/api/{path}")
