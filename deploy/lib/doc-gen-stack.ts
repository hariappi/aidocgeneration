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
