# Runner setup

```
export GLTOKEN="xxxxxxxxxxxxxxx"
export GLURL="https://gitlab.xxxxxx"
gitlab-runner register \
  --non-interactive \
  --request-concurrency 4 \
  --url "${GLURL}" --token "${GLTOKEN}" --executor docker \
  --description "Docker in Docker" \
  --docker-image "docker:git" \
  --docker-pull-policy always --docker-pull-policy always \
  --docker-volumes "/certs/client" \
  --docker-services_privileged=true \
  --docker-allowed-privileged-services='docker:*-dind-rootless' \
  --docker-allowed-privileged-services='docker:dind-rootless' \
  --feature-flags FF_NETWORK_PER_BUILD=ture
```
