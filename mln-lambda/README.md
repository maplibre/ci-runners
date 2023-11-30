# MapLibre Native Lambda

<img src="https://raw.githubusercontent.com/louwers/diagrams/25cf3008fcaeae78f2b8b838fed55239a9145d53/mln-lambda-architecture.drawio.svg" />

This directory contains the code of the serverless function that is used to gather results from continuous benchmarking of MapLibre Native.

An an [AWS Lambda](https://en.wikipedia.org/wiki/AWS_Lambda) function written in TypeScript is used backed by an [Amazon DynamoDB](https://en.wikipedia.org/wiki/Amazon_DynamoDB) database for storage. This setup is chosen because it minimizes the maintenance needed and it integrates well with the other AWS services we use. The source code lives in `lambda/index.ts`.

The setup can be deployed using [AWS CDK](https://en.wikipedia.org/wiki/AWS_Cloud_Development_Kit) (see `./cdk.ts`) with the command `npm run cdk`. AWS CDK is a toolkit for declaratively specifying cloud infrastructure.