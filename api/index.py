from fastapi import FastAPI
from src.app import app

# This is required for Vercel serverless functions
app.root_path = "/api"

# This is required for Vercel
handler = app 