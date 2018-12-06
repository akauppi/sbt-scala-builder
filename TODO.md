# Todo

## Shrink (and understand) the image size

At first, the image was 1.2 GB.

Why does this matter??

If we want to host the image publicly, for others to benefit from, Google's egress charging is by the GB. If we half the size, we can provide twice the downloads (for the same money).

Also, it's just The Right Thing to do. It saves network costs all around.

Rough idea - is it possible?

### Analysis of JDK images

Some JDK images, sorted by size:

|base image|size|comments|
|---|---|---|
|`openjdk:11`|986 MB|
|`openjdk:10`|986 MB|
|`gcr.io/cloud-builders/java/javac:8`|980 MB|Has Docker in addition to `launcher.gcr.io/google/openjdk8`.<sub>[source](https://github.com/GoogleCloudPlatform/cloud-builders/blob/master/javac/Dockerfile)</sub>|
|`openjdk:9`|864 MB|
|`openjdk:12`|467 MB|
|`openjdk:12-alpine`|335 MB|
|`launcher.gcr.io/google/openjdk8`|314 MB|
|`openjdk:8`|624 MB|
|`openjdk:8-alpine`|102 MB|
|`openjdk:11-alpine`|n/a|
|`openjdk:10-alpine`|n/a|
|`openjdk:9-alpine`|n/a|

We can use anything JDK 8 and later for compiling Scala projects.

There is "New builders for Maven and Java 11", [Issue #412](https://github.com/GoogleCloudPlatform/cloud-builders/issues/412) open about these things. Feel free to pitch in there.

#### Outcome?

For the sbt + Scala + Docker, 980 MB might not be that bad. For a docker-less JDK image, there does not seem to be a base image by Google at the moment.

- Making Docker visible in the image name
- If we need a docker-less image at some point, could base that on top of `openjdk:12-alpine` (335 MB)

### After JDK and Docker

What's making the remaining 220 MB?

```
$ docker history eu.gcr.io/sbt-scala/sbt-scala:1.2.7
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
83f0565a36e5        2 hours ago         |4 BASE_URL=https://github.com/sbt/sbt/relea…   167MB               
<missing>           2 hours ago         /bin/sh -c #(nop)  ENTRYPOINT ["/usr/bin/sbt…   0B                  
<missing>           2 hours ago         |4 BASE_URL=https://github.com/sbt/sbt/relea…   55.1MB              
<missing>           2 hours ago         /bin/sh -c #(nop)  ARG _OUT=out.zip             0B                  
<missing>           2 hours ago         /bin/sh -c #(nop)  ARG BASE_URL=https://gith…   0B                  
<missing>           2 hours ago         /bin/sh -c #(nop)  ARG SHA=1e81909fe2ba93168…   0B                  
<missing>           2 hours ago         /bin/sh -c #(nop)  ARG SBT_VERSION=1.2.7        0B                  
<missing>           11 hours ago        /bin/sh -c #(nop)  ENTRYPOINT ["javac"]         0B                  
<missing>           11 hours ago        |1 DOCKER_VERSION=18.06.1~ce~3-0~debian /bin…   667MB               
<missing>           11 hours ago        /bin/sh -c #(nop)  ARG DOCKER_VERSION=18.06.…   0B                  
<missing>           3 weeks ago         /bin/sh -c #(nop)  CMD ["java" "-jar" "app.j…   0B                  
<missing>           3 weeks ago         /bin/sh -c #(nop)  ENTRYPOINT ["/docker-entr…   0B                  
<missing>           3 weeks ago         /bin/sh -c #(nop)  ENV APP_DESTINATION=app.j…   0B                  
<missing>           3 weeks ago         /bin/sh -c tar Cxfvz /opt/cdbg /opt/cdbg/cdb…   14.2MB              
<missing>           3 weeks ago         /bin/sh -c #(nop) COPY dir:6e170fd78283cd3c5…   2.34kB              
<missing>           3 weeks ago         /bin/sh -c #(nop) COPY dir:e750b54fa477b5cec…   2.74kB              
<missing>           3 weeks ago         /bin/sh -c #(nop) COPY file:49f12c7fbc060f00…   1.01kB              
<missing>           3 weeks ago         /bin/sh -c #(nop) ADD 33e19f145fd74c7a4d58b6…   3.16MB              
<missing>           3 weeks ago         /bin/sh -c #(nop) ADD 7bb437d9329197f6453f5d…   2.38MB              
<missing>           3 weeks ago         /bin/sh -c apt-get -q update  && apt-get -y …   192MB               
<missing>           3 weeks ago         /bin/sh -c #(nop)  ENV GAE_IMAGE_LABEL=8-201…   0B                  
<missing>           3 weeks ago         /bin/sh -c #(nop)  ENV GAE_IMAGE_NAME=openjd…   0B                  
<missing>           3 weeks ago         /bin/sh -c #(nop)  ENV OPENJDK_VERSION=8        0B                  
<missing>           3 weeks ago         /bin/sh -c #(nop)  ENV DEBIAN_FRONTEND=nonin…   0B                  
<missing>           48 years ago        bazel build ...                                 103MB  
```

|layer|size|
|---|---|
|installation of sbt|55.1 MB|
|first run of sbt|167 MB|

Guess that's okay.

