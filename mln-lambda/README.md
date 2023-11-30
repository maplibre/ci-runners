# MapLibre Native Lambda

<img src="https://raw.githubusercontent.com/louwers/diagrams/25cf3008fcaeae78f2b8b838fed55239a9145d53/mln-lambda-architecture.drawio.svg" />

This directory contains the code of the serverless function that is used to gather results from continious benchmarking of MapLibre Native.

It is an [AWS Lambda](https://en.wikipedia.org/wiki/AWS_Lambda) function written in TypeScript that uses an [Amazon DynamoDB](https://en.wikipedia.org/wiki/Amazon_DynamoDB) for storage. The source code lives in `lambda/index.ts`.

It can be deployed using [AWS CDK](https://en.wikipedia.org/wiki/AWS_Cloud_Development_Kit) (see `./cdk.ts`) with the command `npm run cdk`.