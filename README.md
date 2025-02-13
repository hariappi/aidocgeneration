# AI Documentation Generator

A web service that automatically generates comprehensive documentation for GitHub repositories using AI.

## Features

- OAuth integration with GitHub
- Automatic code analysis and documentation generation
- Support for multiple programming languages
- Documentation hosted in your repository
- Pull request creation with generated documentation

## Deployment on Vercel

1. Fork this repository

2. Create a GitHub OAuth App:
   - Go to GitHub Settings > Developer settings > OAuth Apps
   - Create New OAuth App
   - Homepage URL: `https://<your-vercel-domain>`
   - Callback URL: `https://<your-vercel-domain>/api/callback`
   - Note down Client ID and Client Secret

3. Install Vercel CLI:
```bash
npm install -g vercel
```

4. Login to Vercel:
```bash
vercel login
```

5. Set up environment variables:
```bash
vercel env add GITHUB_CLIENT_ID
vercel env add GITHUB_CLIENT_SECRET
vercel env add OPENAI_API_KEY
```

6. Deploy to Vercel:
```bash
vercel --prod
```

7. Update the GitHub OAuth App callback URL with your Vercel domain

## Local Development

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Set environment variables:
```bash
export GITHUB_CLIENT_ID="your_github_client_id"
export GITHUB_CLIENT_SECRET="your_github_client_secret"
export OPENAI_API_KEY="your_openai_api_key"
```

3. Run the development server:
```bash
uvicorn api.index:app --reload
```

## API Endpoints

- `GET /` - Home page
- `GET /api/login` - GitHub OAuth login
- `GET /api/callback` - OAuth callback
- `GET /api/repositories` - List user's repositories
- `POST /api/generate/{owner}/{repo}` - Generate documentation

## Environment Variables

- `GITHUB_CLIENT_ID` - GitHub OAuth App client ID
- `GITHUB_CLIENT_SECRET` - GitHub OAuth App client secret
- `OPENAI_API_KEY` - OpenAI API key
- `GITHUB_CALLBACK_URL` - OAuth callback URL (set automatically by Vercel)

## License

MIT License

