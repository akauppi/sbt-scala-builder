# sbt-scala builder

---

Background: 

1. Google Cloud Builder uses Docker images for bringing in the build toolset. 
2. There is a community [scala-sbt](https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/scala-sbt) builder, but it misses a few points and has not been updated in 5 months.
3. Community builders are provided by Google in source mode; you cannot simply use `FROM ...` to use them in your cloud builds.[^1]

This is my take on improving the above situation. 

[^1]: This is completely fine and understandable. It is a slow-down for using Scala projects with Cloud Build, however.

---

Google Cloud Build builder (Docker image) that brings in:

- sbt
- Scala 2.12 (multiple versions is possible)
- Docker[^2]

The purpose is to speed up Cloud Build builds that involve `sbt` and Scala.

Docker support may well be handy if you e.g. are targetting GKE. However, it might be better to bring in at a higher level (now we get it from Google base image).

[^2]: Also the earlier community build brought in Docker, but it was not mentioned anywhere. Now it's added to the name.

## Requirements

- `gcloud` installed and properly configured

## Building locally

```
$ docker build .
```

You don't really benefit much from doing so. You wish the builder to be in the Container Registry, right.

## Pushing to your Container Registry

The Docker image will be pushed to a Google Cloud project's bucket, so please begin by checking which one you are currently logged in with:

```
$ gcloud init
```

Google can do the rest. This fetches the files and builds the image in the cloud.

We use `-t` and the Dockerfile. You could use a `cloudbuild.yaml` as well, but since there's only one image, there's no gain.

Here, we place the image to the European side of Google's cloud. You may use `gcr.io` for the US. Also the `sbt-scala-docker` is just the suggested name for the builder.

```
$ gcloud builds submit -t eu.gcr.io/<your-project>/sbt-scala-docker:1.2.7 .
...
ID                                    CREATE_TIME                DURATION  SOURCE                                                                               IMAGES                                      STATUS
20e8256f-62fa-404c-9e04-4ae528b2b748  2018-12-06T15:32:50+00:00  2M19S     gs://sbt-scala_cloudbuild/source/1544110366.78-ab3e8f08bcf14023bd4cc7fafb6eaf20.tgz  gcr.io/sbt-scala/sbt-scala:1.2.7 (+3 more)  SUCCESS
```

The builder is now built, and the image should be visible in the Container Registry.

```
$ $ gcloud container images list --repository=eu.gcr.io/<your-project>
NAME
eu.gcr.io/sbt-scala/sbt-scala-docker
```

The builder is now available for the project you submitted it for. To make it available for other projects, you need to change the bucket access rights.


### Availability to other specific projects

See [Configuring access control](https://cloud.google.com/container-registry/docs/access-control) (GCP documentation)

### Making it public

Click the "Edit access" here:

![](.images/making-public.png)

---

Note: Google warns that you are eligible for "egress cost" of people using a public image. Let's see how much that is.

Prices vary by destination. The highest (6-Dec-18) is $0.23 per GB (to China). 

Image size is 1.2GB. This means $0.06 from you each time someone (from China) fetches your image.

That's considerable.

---


## Using the builder

From your project's `cloudbuild.yaml`, you can now:

```
- name: 'gcr.io/<your project>/sbt-scala-docker'
  ...
```

But this is not the end, yet. 

If you use the bare builder, all Scala libraries you need will be re-fetched every single build, which slows them down. You can avoid that by deriving a further image that bakes in your most commonly used libraries.


## Pre-caching Scala libraries

This is pretty painless. Follow the same instructions as above, but:

`build.sbt` (just a sample):

```
// Versions of Scala your projects use
// (does not need to match with what base image has and can include different major versions):
//
crossScalaVersions := Seq("2.12.8", "2.12.7")

libraryDependencies ++= Seq(
  "com.typesafe" % "config" % "1.3.3",
  "com.typesafe.scala-logging" %% "scala-logging" % "3.9.0",
  "ch.qos.logback" % "logback-classic" % "1.2.3"
)

val circeVersion = "0.10.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % circeVersion,
  "io.circe" %% "circe-generic" % circeVersion,
  "io.circe" %% "circe-parser" % circeVersion
)

val akkaVer = "2.5.18"
val akkaHttpVer = "10.1.5"
libraryDependencies ++= Seq(
  "com.typesafe.akka" %% "akka-http" % akkaHttpVer,
  "com.typesafe.akka" %% "akka-http-testkit" % akkaHttpVer,
  "com.typesafe.akka" %% "akka-stream" % akkaVer
)

libraryDependencies ++= Seq(
  "org.scalatest" %% "scalatest" % "3.0.5"
)
```

`Dockerfile`:

```
FROM gcr.io/<your project>/sbt-scala-docker:1.2.7

ADD build.sbt build.sbt

RUN sbt "+update" \
  && rm -rf project target
```

Note that any other libraries and versions will be perfectly fine to use, as well. It's just that these get cached into the build image, and as such will not need to be repeatedly fetched.

Enjoy! :)

## Coordinating with the community

If you like this approach, and have time at your hands, it would be appreciated to merge this with the community approach. It's the place where newcomers to Cloud Build + Scala will come for a solution, and the current one is not only dated, but also not fully optimized.

The author can be reached at twitter as `AskoKauppi`. 

## References

- [Google Cloud Build community images](https://github.com/GoogleCloudPlatform/cloud-builders-community) (GitHub) > scala-sbt

- Container Registry > [Configuring access control](https://cloud.google.com/container-registry/docs/access-control) (GCP documentation)

