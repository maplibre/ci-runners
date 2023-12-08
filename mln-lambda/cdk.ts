import "source-map-support/register";
import {
  aws_s3 as s3,
  Stack,
  App,
  StackProps,
  aws_lambda as lambda,
  aws_dynamodb as dynamodb,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import * as apigateway from "aws-cdk-lib/aws-apigateway";

import * as dotenv from "dotenv";

// reads .env file
dotenv.config();

const appName = "mln-lambda";

export class AppStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);
    const bucket = new s3.Bucket(this, `${appName}-bucket`);

    const SIMPLE_SECRET = process.env.SIMPLE_SECRET;
    if (typeof SIMPLE_SECRET !== "string")
      throw new Error("Expected SIMPLE_SECRET environment variable");

    const resultsTable = new dynamodb.Table(
      this,
      `${appName}-dynamodb-results-table`,
      {
        partitionKey: { name: "key", type: dynamodb.AttributeType.STRING },
        billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      }
    );

    resultsTable.addGlobalSecondaryIndex({
      indexName: 'gitRevision-index',
      partitionKey: {
        name: 'gitRevision',
        type: dynamodb.AttributeType.STRING
      }
    });

    const lambdaFunction = new NodejsFunction(
      this,
      `${appName}-nodejs-function`,
      {
        entry: "lambda/index.ts",
        runtime: lambda.Runtime.NODEJS_20_X,
        handler: "handler",
        bundling: {
          minify: false,
        },
        environment: {
          SIMPLE_SECRET,
          RESULTS_TABLE: resultsTable.tableName,
        },
      }
    );
    resultsTable.grantReadWriteData(lambdaFunction);

    const restApi = new apigateway.RestApi(this, `${appName}-rest-api`, {
      defaultIntegration: new apigateway.LambdaIntegration(lambdaFunction),
    });
    restApi.root.addProxy();
  }
}

const app = new App();
new AppStack(app, appName, {
  /* If you don't specify 'env', this stack will be environment-agnostic.
   * Account/Region-dependent features and context lookups will not work,
   * but a single synthesized template can be deployed anywhere. */
  /* Uncomment the next line to specialize this stack for the AWS Account
   * and Region that are implied by the current CLI configuration. */
  // env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
  /* Uncomment the next line if you know exactly what Account and Region you
   * want to deploy the stack to. */
  // env: { account: '123456789012', region: 'us-east-1' },
  /* For more information, see https://docs.aws.amazon.com/cdk/latest/guide/environments.html */
});
