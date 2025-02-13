from fastapi import FastAPI
from src.app import app

# This is required for Vercel serverless functions
handler = app 