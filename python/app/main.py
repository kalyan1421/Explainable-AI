from fastapi import FastAPI
from app.routes import predictions

app = FastAPI(title="Explainable Healthcare AI API")

app.include_router(predictions.router, prefix="/api")

@app.get("/")
async def root():
    return {"message": "Explainable Healthcare AI API", "status": "running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
