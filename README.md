# sbt-scala builder

---

Background: 

1. Google Cloud Builder uses Docker images for bringing in the build toolset. 
2. There is a community [scala-sbt](https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/scala-sbt) builder, but it misses a few points, causes unnecessarily large images (1.2GB) and has not been updated in 5 months.

This is my take on improving the above situation. 

---

Google Cloud Build builder (Docker image) that brings in:

- sbt
- Scala 2.12 (two latest versions)

The purpose is to speed up Cloud Build builds that involve `sbt` and Scala, and to provide the slimmest image for doing so. 

This image can be used as-is, or as a base image for bringing in project specific libraries (to further speed up your actual build case).

## Requirements

- `gcloud` installed and properly configured

The Docker image will be pushed to the Container Registry (and Google Cloud Storage bucket) of the project you are currently logged in as. Check this before proceding:

```
$ gcloud init
```

---

Note: If you plan to use a single builder for all of your Google Cloud projects, or host the builder for other accounts as well, it may be good to set up a separate project just for the builder. The project name will show in the name of the builder step for those using it.

---

Recommended (optional):

- `docker`
- [dive](https://github.com/wagoodman/dive) - "A tool for exploring each layer in a docker image"



## Build the image locally (optional)

You can do this simply to see that the build succeeds.

```
$ docker build .
...
Successfully built 29a6e8655e15
```

It should result in an image of ~490MB in size, containing:

- JDK
- sbt pre-installed
- Scala 2.12 language libraries loaded (but no `scala` command line tool)


## Pushing to your Container Registry

A single `gcloud` command will fetch the necessary files, build the image in the cloud side, and push it to your project's Container Registry.

We place the images to the European `eu.gcr.io`. If you wish otherwise, edit `cloudbuild.yaml` before running `gcloud builds submit`.

---

Note: If `gcloud builds submit` respected multiple tag parametets (like `docker build` does), we could build without needing the `cloudbuild.yaml`. Now, we need it, in order to push both versioned (`sbt-scala:1.2.7-jdk8`) and latest (`sbt-scala:latest`).

---

```
$ gcloud builds submit .
...
ID                                    CREATE_TIME                DURATION  SOURCE                                                                                IMAGES                                     STATUS
5ef438bd-da5a-46bc-aaeb-84dfa70fe227  2018-12-09T10:24:10+00:00  1M51S     gs://asu-181118_cloudbuild/source/1544351046.98-4a98e7eb6fea44b09e1c326af9b0551c.tgz  eu.gcr.io/asu-181118/sbt-scala:1.2.7-jdk8  SUCCESS
```

The "source" (bucket mentioned above) contains copies of all the files in this directory. That's what `gcloud` built the builder from.

The "images" shows the name of the image that you can now use for builds within this same project. 


### Availability to other projects

To make the image available for your other projects, you need to grant access rights to the underlying Google Cloud Storage bucket.

- Go to [Google Cloud Platform Console](https://console.cloud.google.com) > Storage > Browser
- Pick the "[eu.]artifacts.<project id>.appspot.com" bucket

  ![](.images/browse-bucket.png)

	- `⋮` > `Edit bucket permissions`
		- Add an email address (for a service account?) and grant right `Storage > Storage Object Viewer` right

		Note: To see, which email addresses you can use, the help hover icon is great:
		
  		![](.images/add-users-help.png)


<!-- disabled
### Making it public

Click the "Edit access" here:

![](.images/making-public.png)

- - -

Note: Google warns that you are eligible for "egress cost" of people using a public image. Let's see how much that is.

Prices vary by destination. The highest (6-Dec-18) is $0.23 per GB (to China). 

Image size is 1.2GB. This means $0.06 from you each time someone (from China) fetches your image.

That's considerable.

- - -
-->

## Using the builder

From your project's `cloudbuild.yaml`, you can now:

```
- name: 'gcr.io/<your project>/sbt-scala'
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
FROM eu.gcr.io/<your builder project>/sbt-scala:1.2.7-jdk8

ADD build.sbt build.sbt

RUN sbt "+update" \
  && rm -rf project target
```

To submit your derived builder from simply a `Dockerfile`:

```
$ export PROJECT_ID = $(gcloud config get-value project 2> /dev/null)
$ gcloud builds submit -t eu.gcr.io/$PROJECT_ID/sbt-scala-primed .
```

---

Note: Whatever you call your builder is of course up to you. The `-primed` used above feels good - it's like spreading a primer paint before the real one. Once the real paint (your real build) is there, the primer no longer shows. :)

---

Note that any other libraries and versions will be perfectly fine to use, as well. It's just that these get cached into the build image, and as such will not need to be repeatedly fetched.

### If you need Docker

You probably don't.

Your Cloud Build steps can be kept separate for Scala builds, and for dockerization. If this is the case, you won't need Docker in the sbt-scala image. :)

If you build your Docker image using some "helper" framework like [sbt-native-packager](https://www.scala-sbt.org/sbt-native-packager/index.html)'s Docker plugin, you need Docker in your sbt builder image.

In this case, add it into your derived builder by copy-pasting from [here](https://github.com/GoogleCloudPlatform/cloud-builders/blob/master/javac/Dockerfile).

```
ARG DOCKER_VERSION=18.06.1~ce~3-0~debian

# Install Docker based on instructions from:
# https://docs.docker.com/engine/installation/linux/docker-ce/debian
RUN \
   apt-get -y update && \
   apt-get --fix-broken -y install && \
   apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common && \
   curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
   apt-key fingerprint 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 && \
   add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/debian \
      $(lsb_release -cs) \
      stable" && \
   apt-get -y update && \
   apt-get -y install docker-ce=${DOCKER_VERSION} && \

   # Clean up build packages
   apt-get remove -y --purge curl gnupg2 software-properties-common && \
   apt-get clean
```   

We could also provide two base images in this repo: `sbt-scala` and `sbt-scala-docker`.


## Coordinating with the community

If you like this approach, and have time at your hands, it would be appreciated to merge this with the community approach. It's the place where newcomers to Cloud Build + Scala will come for a solution, and the current one is not only dated, but also not fully optimized.

The author can be reached at twitter as `AskoKauppi`. 

## References

- [Google Cloud Build community images](https://github.com/GoogleCloudPlatform/cloud-builders-community) (GitHub) > scala-sbt

- Container Registry 
	- [Configuring access control](https://cloud.google.com/container-registry/docs/access-control) (GCP documentation)

