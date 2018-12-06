#
# Dockerfile
#
# Based on https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/scala-sbt
#
# Changes:
#   Naming:
#     - naming as 'sbt-scala-docker' since a) sbt is more important than Scala (in this context), b) Docker is implicitly
#       included in Google's `javac:8` base image.
#   Versions:
#     - More current sbt version (1.0.2 -> 1.2.7)
#     - JDK version not mentioned in the version - it matters less for Scala builds
#   Usage:
#     - Not needing `cloudbuild.yaml` since only one image is created (only sbt 1.x provided)
#   Internal:
#     - uses a fixed intermediate file name ("out.zip")
#     - removed installation of 'bc' (what needed that, maybe a copy-paste?)
#   Features:
#     - pre-fetches Scala libraries (earlier does not, despite its name)
#     - 'sbt' is launched once, which is when it fetches its own underlying libraries (earlier does not)
#
# Note:
#   Google recommends that builders run a "sanity check" command (i.e. execute the installed tool), but the earlier
#   image does not do this.
#
# Note:
#   "Installing sbt on Linux" suggests using apt-get, instead of raw curl download (that used to be the way).
#   We follow the curl/unzip route of the community builder at least for now. It does work.
#       -> https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html
#

#---
# This is 940 MB and also carries Docker with it.
#   - base image sources -> https://github.com/GoogleCloudPlatform/cloud-builders/tree/master/javac
#   - New builders for Maven and Java 11 (Issue 412) -> https://github.com/GoogleCloudPlatform/cloud-builders/issues/412
#
FROM gcr.io/cloud-builders/java/javac:8

# sbt version is only here (no 'project/build.properties' file)
#
ARG SBT_VERSION=1.2.7
ARG SHA=1e81909fe2ba931684263fa58e9710e41ab50fe66bb0c20d274036db42caa70e
ARG BASE_URL=https://github.com/sbt/sbt/releases/download
ARG _OUT=out.zip

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

# Running 'sbt' is needed, in order for it to download required libraries.
# This also loads the language libraries of Scala versions given.
#
# Note: It seems we cannot provide the build definition from stdin.
#
RUN echo 'crossScalaVersions := Seq("2.12.8", "2.12.7")' > temp.sbt \
  && sbt "+update" \
  && rm temp.sbt \
  && rm -rf project target
