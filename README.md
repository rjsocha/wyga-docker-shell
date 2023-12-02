# wyga/docker-shell

This Docker image is designed specifically for serving as a GitLab CI runner in Docker in Docker builds. It's built on Ubuntu 22.04 and comes with **bash** present.

When the environment variable **DOCKER_CREATE_CONTEXT** is present, the image automatically initiates the creation of a Docker context named **dind** configured for the **docker** service.

Include this image in your GitLab CI pipeline's `.gitlab-ci.yml` file:

```yaml
image: wyga/docker-shell:latest
```

## Runner setup

```
{
  export GLTOKEN="xxxxxxxxxxxxxxx"
  export GLURL="https://gitlab.xxxxxx"
  export GRNAME="docker-in-docker"
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
  --docker-services-privileged=true \
  --docker-allowed-privileged-services='**/docker:dind' \
  --docker-allowed-privileged-services='**/docker:*-dind' \
  --feature-flags FF_NETWORK_PER_BUILD \
  --feature-flags FF_USE_FASTZIP
}
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
