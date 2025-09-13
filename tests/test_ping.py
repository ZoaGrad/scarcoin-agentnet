import pytest
from httpx import ASGITransport, AsyncClient
from scarcoin_agentnet.main import app

@pytest.mark.asyncio
async def test_ping():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        r = await ac.get("/ping")
    assert r.status_code == 200
    assert r.json()["status"] == "alive"
