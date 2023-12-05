This directory contains custom test environments for AWS Device Farm.

I need one to pass arguments to [AndroidJUnitRunner](https://developer.android.com/reference/androidx/test/runner/AndroidJUnitRunner) that specify which tests to run. For example:

```
am instrument -w -e notClass org.maplibre.android.benchmark.Benchmark
```

to run all tests but exclude the benchmark.

The file `default-android.yaml` contains the default test environment for reference. It is not uploaded. To use it, don't specify a custom test environment when running a test. I uploaded `android-ui-test.yaml` using:

```
aws devicefarm create-upload --name android-ui-test.yaml --type INSTRUMENTATION_TEST_SPEC --project-arn arn:aws:devicefarm:us-west-2:373521797162:project:20687d72-0e46-403e-8f03-0941850665bc
curl -T android-ui-test.yaml <url>
```

The ARN is `arn:aws:devicefarm:us-west-2:373521797162:upload:20687d72-0e46-403e-8f03-0941850665bc/09e0738e-c91e-4c5f-81e6-06a06cc340d8`.

## Resources

- [Working with custom test environments in AWS Device Farm](https://docs.aws.amazon.com/devicefarm/latest/developerguide/custom-test-environments.html)
- [Upload your custom test spec](https://docs.aws.amazon.com/devicefarm/latest/developerguide/how-to-create-test-run.html#how-to-create-test-run-cli-step5)