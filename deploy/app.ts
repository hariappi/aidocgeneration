import * as cdk from 'aws-cdk-lib';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as ecs_patterns from 'aws-cdk-lib/aws-ecs-patterns';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';

export class DocGenStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create ECR Repository
    const repository = new ecr.Repository(this, 'DocGenRepository', {
      repositoryName: 'ai-doc-generator',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Create Fargate Service
    const loadBalancedService = new ecs_patterns.ApplicationLoadBalancedFargateService(this, 'DocGenService', {
      memoryLimitMiB: 1024,
      cpu: 512,
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

    // Output the load balancer URL
    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: loadBalancedService.loadBalancer.loadBalancerDnsName,
    });
  }
} 