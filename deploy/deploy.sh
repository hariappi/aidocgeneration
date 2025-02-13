#!/bin/bash
set -e

# Check for AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    echo "Error: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Using AWS Account: $AWS_ACCOUNT_ID in region: $AWS_REGION"

# Setup deploy directory structure
echo "Setting up deployment directory..."
mkdir -p deploy/bin deploy/lib
cd deploy

# Initialize npm project if needed
if [ ! -f package.json ]; then
    echo "Initializing npm project..."
    npm init -y
fi

# Install dependencies
echo "Installing dependencies..."
npm install aws-cdk-lib@2.178.2 constructs@10.4.2 \
    typescript@4.9.5 ts-node@10.9.2 @types/node@14.18.63 \
    aws-cdk

# Create TypeScript config
echo "Creating TypeScript config..."
cat > tsconfig.json << 'EOL'
{
  "compilerOptions": {
    "target": "ES2018",
    "module": "commonjs",
    "lib": ["es2018"],
    "declaration": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": false,
    "inlineSourceMap": true,
    "inlineSources": true,
    "experimentalDecorators": true,
    "strictPropertyInitialization": false,
    "typeRoots": ["./node_modules/@types"],
    "outDir": "dist"
  },
  "include": ["bin/**/*", "lib/**/*"]
}
EOL

# Create CDK app file
echo "Creating CDK app..."
cat > bin/app.ts << 'EOL'
#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { DocGenStack } from '../lib/doc-gen-stack';

const app = new cdk.App();
new DocGenStack(app, 'DocGenStack', {
  env: { 
    account: process.env.CDK_DEFAULT_ACCOUNT, 
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1'
  },
});
EOL

# Create stack file
echo "Creating CDK stack..."
cat > lib/doc-gen-stack.ts << 'EOL'
import * as cdk from 'aws-cdk-lib';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as ecs_patterns from 'aws-cdk-lib/aws-ecs-patterns';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as ec2 from 'aws-cdk-lib/aws-ec2';

export class DocGenStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'DocGenVPC', { maxAzs: 2 });
    const cluster = new ecs.Cluster(this, 'DocGenCluster', { vpc });
    
    const repository = new ecr.Repository(this, 'DocGenRepository', {
      repositoryName: 'ai-doc-generator',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const service = new ecs_patterns.ApplicationLoadBalancedFargateService(this, 'DocGenService', {
      cluster,
      memoryLimitMiB: 2048,
      cpu: 1024,
      taskImageOptions: {
        image: ecs.ContainerImage.fromEcrRepository(repository),
        environment: {
          GITHUB_CALLBACK_URL: process.env.GITHUB_CALLBACK_URL || '',
        },
        secrets: {
          GITHUB_CLIENT_ID: ecs.Secret.fromSecretsManager(
            secretsmanager.Secret.fromSecretNameV2(this, 'GitHubClientId', 'github-client-id')
          ),
          GITHUB_CLIENT_SECRET: ecs.Secret.fromSecretsManager(
            secretsmanager.Secret.fromSecretNameV2(this, 'GitHubClientSecret', 'github-client-secret')
          ),
          OPENAI_API_KEY: ecs.Secret.fromSecretsManager(
            secretsmanager.Secret.fromSecretNameV2(this, 'OpenAIKey', 'openai-api-key')
          ),
        },
      },
      publicLoadBalancer: true,
    });
  }
}
EOL

# Build TypeScript
echo "Building TypeScript..."
./node_modules/.bin/tsc

# Bootstrap CDK
echo "Bootstrapping CDK..."
./node_modules/.bin/cdk bootstrap

# Build and push Docker image
cd ..
echo "Building Docker image..."
docker build -t ai-doc-generator .

# Create ECR repository if needed
if ! aws ecr describe-repositories --repository-names ai-doc-generator &>/dev/null; then
    echo "Creating ECR repository..."
    aws ecr create-repository --repository-name ai-doc-generator
fi

# Push to ECR
echo "Pushing to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker tag ai-doc-generator:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ai-doc-generator:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ai-doc-generator:latest

# Deploy
echo "Deploying stack..."
cd deploy
./node_modules/.bin/cdk deploy --require-approval never

echo "Deployment complete!" 