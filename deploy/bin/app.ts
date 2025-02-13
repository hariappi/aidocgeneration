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
