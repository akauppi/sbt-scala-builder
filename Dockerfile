#
# Dockerfile
#
# Based on https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/scala-sbt
#
# Changes:
#   - More current sbt version (1.0.2 -> 1.2.7)
#   - uses a fixed intermediate file name ("out.zip")
#   - pre-fetches Scala libraries for some recent versions
#   - fixing to JVM 8 (latest available from Google), instead of being dynamic from `cloudbuild.yaml`
#   - naming as 'sbt-scala' since sbt is more important
#   - 'sbt' is launched once, which is when it fetches its own underlying libraries
#
# For users:
#   You may want to further reduce build times by pre-fetching frequently used libraries. Derive your image from this
#   one. See `README` for instructions.
#
# Note:
#   "Installing sbt on Linux" suggests using apt-get, instead of raw curl download (that used to be the way).
#   However, we follow the curl/unzip route of the community builder at least for now. It does work.
#
#   See -> https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html
#

# Latest javac image from Google:
#   -> https://github.com/GoogleCloudPlatform/cloud-builders/tree/master/javac
#
FROM gcr.io/cloud-builders/java/javac:8

# sbt version is only here (no 'project/build.properties' file)
#
ARG SBT_VERSION=1.2.7
ARG SHA=1e81909fe2ba931684263fa58e9710e41ab50fe66bb0c20d274036db42caa70e
ARG BASE_URL=https://github.com/sbt/sbt/releases/download
ARG _OUT=out.zip

RUN apt-get update -qqy \
  && apt-get install -qqy curl bc \
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
RUN echo 'crossScalaVersions := Seq("2.12.8", "2.12.7")' > build.sbt \
  && sbt "+update" \
  && rm build.sbt \
  && rm -rf project target
