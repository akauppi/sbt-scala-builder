#
# Dockerfile
#
# Based on https://github.com/GoogleCloudPlatform/cloud-builders-community/tree/master/scala-sbt
#
# Changes:
#   Naming:
#     - naming as 'sbt-scala' since sbt is more important than Scala in this context
#   Versions:
#     - More current sbt version (1.0.4 -> 1.2.8)
#   Contents:
#     - Avoiding Docker installation (done implicitly by Google's 'javac' image), to reduce size.
#     - Only building one image (no 0.13.x for legacy); however your project may of course specify any version it
#       wants for project compilation ('project/build.properties').
#   Usage:
#     - no 'cloudbuild.yaml' since we only build one image
#   Internal:
#     - uses a fixed intermediate file name ("out.zip")
#     - removed installation of 'bc' (looks like a copy-paste remnant that wasn't needed)
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

# Rather build as a user, not root.
#
# Ideas from -> https://stackoverflow.com/questions/27701930/add-user-to-docker-container
#
WORKDIR /build

ADD build.sbt .

# Be eventually a user rather than root
#
RUN useradd -ms /bin/bash user
RUN chown -R user /build

# Installation of 'sbt' (as root)
#
# Note: The original builder uses 'curl' to fetch the sources. Compared to the recommended 'sbt' way [1], this is
#     longer but avoids installing 'gnupg' (needed for 'apt-key adv') and some warning messages. Likely worth it.
#
# The sbt installed in this way is simply the version available on command-line. It will automatically download (also)
# the latest (and create 'project/build.properties'). However, we do know the version mentioned here is available.
#
# [1]: sbt > Ubuntu and other Debian-based distributions
#     --> https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html#Ubuntu+and+other+Debian-based+distributions
#
ARG SBT_VER=1.2.8
ARG SBT_SHA=f4b9fde91482705a772384c9ba6cdbb84d1c4f7a278fd2bfb34961cd9ed8e1d7
ARG _URL=https://github.com/sbt/sbt/releases/download
ARG _OUT=out.zip

RUN apt-get update -qqy \
  && apt-get install -qqy curl \
  && mkdir -p /usr/share \
  && curl -fsSL -o ${_OUT} "${_URL}/v${SBT_VER}/sbt-${SBT_VER}.zip" \
  && echo ${SBT_SHA} ${_OUT} | sha256sum -c - \
  && unzip -qq ${_OUT} \
  && rm -f ${_OUT} \
  && mv sbt "/usr/share/sbt-${SBT_VER}" \
  && ln -s "/usr/share/sbt-${SBT_VER}/bin/sbt" /usr/bin/sbt \
  && apt-get remove -qqy --purge curl \
  && rm /var/lib/apt/lists/*_*

ENTRYPOINT ["/usr/bin/sbt"]

# Now changing to user (no more root)
USER user

# Running 'sbt' once is needed, in order to download required libraries. This also loads the right version of 'sbt' and
# the language libraries for Scala.
#
# Note: Set of Scala versions supported can be extended in one's derived builder image. The union of these will be
#       cached.
#
# Note: It seems we cannot provide the build definition from stdin.
#
# Note: Use '+compile' instead of '+update' to also pre-compile 'compiler-bridge_2.12'.
#
RUN sbt "+compile" \
  && rm -rf project target
