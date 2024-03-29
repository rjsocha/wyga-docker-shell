# wyga/docker-shell

This Docker image is designed specifically for serving as a GitLab CI image in Docker in Docker builds. It's built on Ubuntu 22.04 and comes with **bash** present.

When the environment variable **DOCKER_CREATE_CONTEXT** is present, the image automatically initiates the creation of a Docker context named **dind** configured for the **docker** service.

Include this image in your GitLab CI pipeline's `.gitlab-ci.yml` file:

```yaml
image: wyga/docker-shell:latest
```

## Runner setup

```
{
  GLTOKEN="xxxxxxxxxxxxxxx"
  GLURL="https://gitlab.xxxxxx"
  GRNAME="docker-in-docker"
}
```

```
{
gitlab-runner register \
  --non-interactive \
  --url "${GLURL}" --token "${GLTOKEN}" --executor docker \
  --description "${GRNAME}" \
  --docker-image "docker:git" \
  --docker-pull-policy always --docker-pull-policy always \
  --docker-volumes "/certs/client" \
  --docker-services_privileged=true \
  --docker-services-limit=-1 \
  --docker-allowed-privileged-services='**/docker:dind' \
  --docker-allowed-privileged-services='**/docker:*-dind' \
  --feature-flags FF_NETWORK_PER_BUILD \
  --feature-flags FF_USE_FASTZIP
}
```

## Cleanup job

```
 (crontab -l 2>/dev/null; \
 printf -- '30 5 * * *'; \
 printf -- ' docker volume prune --all --force >/dev/null &&'; \
 printf -- ' docker system prune --force >/dev/null\n'; \
 printf -- '30 4 * * 0'; \
 printf -- ' docker system prune --force --all >/dev/null\n';) | crontab -
```

## Parameter Descriptions

Allows GitLab Runner to retry image download if the first attempt fails

```
 --docker-pull-policy always --docker-pull-policy always
```


Allows to use images from docker.io and via [Gitlab's Dependency Proxy](https://docs.gitlab.com/ee/user/packages/dependency_proxy/)

```
 --docker-allowed-privileged-services='**/docker:dind'
 --docker-allowed-privileged-services='**/docker:*-dind'
```
