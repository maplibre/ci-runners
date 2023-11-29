import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBClient, ScanCommand } from "@aws-sdk/client-dynamodb";
import {
  PutCommand,
  DynamoDBDocumentClient,
  DynamoDBDocument,
} from "@aws-sdk/lib-dynamodb";
import * as uuid from "uuid";

const SIMPLE_SECRET = process.env.SIMPLE_SECRET;
if (typeof SIMPLE_SECRET !== "string") {
  throw new Error("Expected SIMPLE_SECRET environment variable");
}

function makeResponse(obj: any) {
  return {
    body: JSON.stringify(obj),
    statusCode: 200,
    isBase64Encoded: false,
    headers: {
      "Content-Type": "application/json",
    },
  };
}

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  const client = new DynamoDBClient({ region: "us-west-2" });
  const docClient = DynamoDBDocument.from(client, {
    unmarshallOptions: {},
  });

  if (event.path.includes(SIMPLE_SECRET)) {
    // when POST, dump JSON body in database
    if (event.httpMethod == "POST") {
      if (typeof event.body !== "string") throw new Error("Expected JSON body");
      console.log("body", event.body);
      const parsed = JSON.parse(event.body);
      parsed.key = uuid.v4();
      const results = await docClient.put({
        TableName: process.env.RESULTS_TABLE!,
        Item: parsed,
      });
      return makeResponse(results);
    }
  }

  const results = await docClient.scan({
    TableName: process.env.RESULTS_TABLE!,
  });

  return makeResponse(results.Items);
};