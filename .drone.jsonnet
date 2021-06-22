/* Docker images */
local images = {
  python: 'python:3.7-alpine@sha256:deaefc5e07ef1f3420411dd5225b2fc2ab23ae7731e8cb216d9fe74557d81db5',
};

/* Base configuration for most pipeline steps */
local base = { pull: 'if-not-exists' };
local base_node = base { image: images.python };


local failed_step(
  name,
  output='',
  exit_code=1
      ) =
  base_node {
    name: name,
    commands: ['echo -e "' + name + '"'] + ['echo -e ' + std.escapeStringBash(output)] + ['exit ' + exit_code],
//    when: { event: 'push' },
  };

local success_step(
  name,
  output='',
  commands=[],
  delay=0
      ) =
  base_node {
    name: name,
    commands: ['echo -e "' + name + '"'] + ['sleep ' + delay + ''] + commands,
//    when: { event: 'push' },
  };

local docker_pipeline(name, steps=[]) =
  {
    kind: 'pipeline',
    type: 'docker',
    name: name,
    steps: steps,
  };

/* Main pipeline */
[
  docker_pipeline('success', [
    success_step('build', delay=0, commands=[
      'pip install pytest pytest-cov'
    ]),
    success_step('unit tests', delay=2),
    success_step('integration tests', delay=5),
    success_step('component tests', delay=10),
    success_step('functional tests', delay=15),
    success_step('e2e tests', delay=30),
  ]),
  docker_pipeline('error', [
    failed_step('slack server error'),
    failed_step('verify docs', 'please run prettier:docs to fix this issue'),
    failed_step('connection refused', 'samizdat ECONNREFUSED'),
    failed_step('merge conflict', 'Automatic merge failed; fix conflicts in your git branch'),
    failed_step('yarn dependencies', "Couldn't find any versions for \"react\""),
  ]),
  docker_pipeline('webhooks', [
    {
      name: 'webhook',
      image: 'plugins/webhook',
      failure: 'ignore',
      settings: {
        username: 'myusername',
        password: 'mypassword',
        urls: 'https://drone-ci-butler.ngrok.io/hooks/drone',
        skip_verify: true,
        debug: true,
      },
    },
  ]),
]
