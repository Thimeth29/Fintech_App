"""HTTP with a browser-like user agent, timeouts and retries."""
from __future__ import annotations

import time

import requests

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0 Safari/537.36")
TIMEOUT = 30


def _request(method: str, url: str, retries: int = 2, **kw) -> requests.Response:
    headers = {"user-agent": UA, **kw.pop("headers", {})}
    last: Exception | None = None
    for attempt in range(retries + 1):
        try:
            res = requests.request(method, url, headers=headers, timeout=TIMEOUT, **kw)
            # Back off on rate limiting / server errors, then try again.
            if res.status_code == 429 or res.status_code >= 500:
                raise requests.HTTPError(f"HTTP {res.status_code}", response=res)
            res.raise_for_status()
            return res
        except requests.RequestException as e:
            last = e
            if attempt < retries:
                time.sleep(2 * (attempt + 1))
    raise last  # type: ignore[misc]


def get(url: str, **kw) -> requests.Response:
    return _request("GET", url, **kw)


def post(url: str, **kw) -> requests.Response:
    return _request("POST", url, **kw)
