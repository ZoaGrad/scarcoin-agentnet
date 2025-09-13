from fastapi import FastAPI

app = FastAPI(title="ScarCoin AgentNet", version="0.1.0")

@app.get("/ping")
def ping():
    return {"status": "alive", "agent": "agentnet"}
