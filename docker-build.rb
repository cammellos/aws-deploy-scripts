require 'aws-sdk'

target = ENV['DOCKER_USER']
service = ARGV[0]
directory = ARGV[1]

Docker.authenticate!('username' => target, 'password' => ENV['DOCKER_PASS'], 'email' => ENV['DOCKER_EMAIL'])

puts "Building image..."

image = Docker::Image.build_from_dir(directory) do |v|
  if (log = JSON.parse(v)) && log.has_key?("stream")
    $stdout.puts log["stream"]
  end
end

puts "Pushing image..."

image.tag('repo' => service, 'tag' => 'latest', force: true)

image.push(nil, repo_tag: "#{target}/#{service}:latest") 

puts "Image pushed..."

Aws.config.update({
  region: 'eu-west-1',
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
})

client = Aws::ECS::Client.new

container_definitions = client.describe_task_definition({task_definition: service}).task_definition.container_definitions.map(&:to_h)
new_revision = client.register_task_definition family: service, container_definitions: container_definitions
client.update_service cluster: service, service: service, desired_count: 0

while client.list_tasks(cluster: service, family: service).task_arns.count != 0 do
  puts 'waiting for service to scale down'
  sleep 1
end

client.update_service cluster: service, service: service, desired_count: 1, task_definition: new_revision.task_definition.task_definition_arn.split("/").last
while client.list_tasks(cluster: service, family: service).task_arns.count != 1 do
  puts 'waiting for service to scale up'
  sleep 1
end

puts 'deployed!'

