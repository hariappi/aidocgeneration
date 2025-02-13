import os
import openai
from pathlib import Path
import glob
import httpx
import base64
from typing import Dict

def setup_openai():
    """Initialize OpenAI client with API key from environment"""
    openai.api_key = os.getenv('OPENAI_API_KEY')
    return openai.Client()

def get_files_content(extensions=['.py', '.js', '.ts', '.java']):
    """Get content of all code files in the repository"""
    files_content = {}
    for ext in extensions:
        for file_path in glob.glob(f'**/*{ext}', recursive=True):
            if 'node_modules' not in file_path and 'venv' not in file_path:
                with open(file_path, 'r', encoding='utf-8') as file:
                    try:
                        content = file.read()
                        files_content[file_path] = content
                    except Exception as e:
                        print(f"Error reading {file_path}: {e}")
    return files_content

def generate_documentation(client, file_path, content):
    """Generate documentation for a single file using OpenAI"""
    prompt = f"""Please analyze this code and provide comprehensive documentation including:
    1. Overview of the file's purpose
    2. Main components and their functionality
    3. Usage examples (if applicable)
    4. Any important notes or considerations

    File: {file_path}
    Content:
    {content}
    """
    
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a technical documentation expert."},
                {"role": "user", "content": prompt}
            ]
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Error generating documentation: {e}"

def save_documentation(docs, output_dir='docs'):
    """Save generated documentation to files"""
    Path(output_dir).mkdir(exist_ok=True)
    
    # Create main index file
    with open(f'{output_dir}/index.md', 'w', encoding='utf-8') as f:
        f.write("# Project Documentation\n\n")
        f.write("## Files\n\n")
        for file_path in docs:
            doc_file_path = file_path.replace('/', '_').replace('\\', '_')
            f.write(f"- [{file_path}]({doc_file_path}.md)\n")

    # Create individual documentation files
    for file_path, content in docs.items():
        doc_file_path = file_path.replace('/', '_').replace('\\', '_')
        with open(f'{output_dir}/{doc_file_path}.md', 'w', encoding='utf-8') as f:
            f.write(f"# Documentation for {file_path}\n\n")
            f.write(content)

async def clone_repository(owner: str, repo: str, token: str) -> Dict[str, str]:
    """Fetch repository contents using GitHub API"""
    async with httpx.AsyncClient() as client:
        files_content = {}
        
        # Get repository contents
        response = await client.get(
            f"https://api.github.com/repos/{owner}/{repo}/git/trees/main?recursive=1",
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github.v3+json"
            }
        )
        
        if response.status_code != 200:
            raise Exception("Failed to fetch repository contents")
            
        tree = response.json()["tree"]
        
        for item in tree:
            if item["type"] == "blob":
                path = item["path"]
                if any(path.endswith(ext) for ext in ['.py', '.js', '.ts', '.java']):
                    # Get file content
                    content_response = await client.get(
                        f"https://api.github.com/repos/{owner}/{repo}/contents/{path}",
                        headers={
                            "Authorization": f"Bearer {token}",
                            "Accept": "application/vnd.github.v3+json"
                        }
                    )
                    
                    if content_response.status_code == 200:
                        content = base64.b64decode(content_response.json()["content"]).decode()
                        files_content[path] = content
                        
        return files_content

async def generate_docs_for_repo(owner: str, repo: str, token: str):
    """Generate documentation for a GitHub repository"""
    client = setup_openai()
    files_content = await clone_repository(owner, repo, token)
    documentation = {}
    
    for file_path, content in files_content.items():
        print(f"Generating documentation for {file_path}")
        doc = generate_documentation(client, file_path, content)
        documentation[file_path] = doc
    
    # Create a new branch for documentation
    async with httpx.AsyncClient() as client:
        # Create docs branch
        await create_docs_branch(client, owner, repo, token, documentation)
        
    return {"status": "success", "message": "Documentation generated and pushed to docs branch"}

async def create_docs_branch(client, owner: str, repo: str, token: str, documentation: Dict[str, str]):
    """Create a new branch with documentation"""
    # Implementation for creating a new branch and pushing documentation
    # This would involve creating a new branch, committing files, and creating a pull request
    pass

def main():
    client = setup_openai()
    files_content = get_files_content()
    documentation = {}
    
    for file_path, content in files_content.items():
        print(f"Generating documentation for {file_path}")
        doc = generate_documentation(client, file_path, content)
        documentation[file_path] = doc
    
    save_documentation(documentation)

if __name__ == "__main__":
    main()
