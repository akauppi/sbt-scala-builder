#
# Dockerfile
#
# Based on https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/scala-sbt
#
# Changes:
#   Naming:
#     - naming as 'sbt-scala' since sbt is more important than Scala in this context
#   Versions:
#     - More current sbt version (1.0.4 -> 1.2.7)
#   Contents:
#     - Avoiding Docker installation (done implicitly by Google's 'javac' image), to reduce size.
#     - Only building one image (no 0.13.x for legacy); however your project may of course specify any version it
#       wants for project compilation ('project/build.properties').
#   Usage:
#     - no 'cloudbuild.yaml' since we only build one image
#   Internal:
#     - uses a fixed intermediate file name ("out.zip")
#     - removed installation of 'bc' (looks like a copy-paste remnant; was it needed?)
#   Fixes:
#     - pre-fetches Scala libraries (earlier does not, despite its name)
#     - 'sbt' is launched once, which is when it fetches its own underlying libraries (earlier does not)
#

#---
# Using the base image of Google's 'javac' image. This leaves addition of Docker to the application (derived image) level.
#
# Note: Google does not offer JDK 9+ at this point (Dec-18). You can try using a public OpenJDK image here.
#
FROM launcher.gcr.io/google/openjdk8
    #was: gcr.io/cloud-builders/java/javac:8

# sbt version is only here (no 'project/build.properties' file)
#
ARG SBT_VERSION=1.2.7
ARG SHA=1e81909fe2ba931684263fa58e9710e41ab50fe66bb0c20d274036db42caa70e
ARG BASE_URL=https://github.com/sbt/sbt/releases/download
ARG _OUT=out.zip

# Installation of 'sbt'
#
# Note:
#   sbt docs > "Installing sbt on Linux"[1] suggests using apt-get, instead of raw curl download (that used to be the
#   way). We follow the curl/unzip route of the community builder at least for now. It does work.
#
#   [1]: https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html
#
RUN apt-get update -qqy \
  && apt-get install -qqy curl \
  && mkdir -p /usr/share \
  && curl -fsSL -o ${_OUT} "${BASE_URL}/v${SBT_VERSION}/sbt-${SBT_VERSION}.zip" \
  && echo ${SHA} ${_OUT} | sha256sum -c - \
  && unzip -qq ${_OUT} \
  && rm -f ${_OUT} \
  && mv sbt "/usr/share/sbt-${SBT_VERSION}" \
  && ln -s "/usr/share/sbt-${SBT_VERSION}/bin/sbt" /usr/bin/sbt \
  && apt-get remove -qqy --purge curl \
  && rm /var/lib/apt/lists/*_*

ENTRYPOINT ["/usr/bin/sbt"]

# Running 'sbt' once is needed, in order to download required libraries. This also loads the language libraries for Scala.
#
# Note: Set of Scala versions supported can be extended in one's derived builder image. The union of these will be
#       cached.
#
# Note: It seems we cannot provide the build definition from stdin.
#
RUN echo 'crossScalaVersions := Seq("2.12.8", "2.12.7")' > primer.sbt \
  && sbt "+update" \
  && rm primer.sbt \
  && rm -rf project target
