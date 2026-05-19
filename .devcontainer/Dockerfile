# Dev container for Unrecorded — Flutter stable + Android SDK (CI parity).
FROM ghcr.io/cirruslabs/flutter:stable

ARG ANDROID_SDK_ROOT=/opt/android-sdk
ARG DEBIAN_FRONTEND=noninteractive

ENV ANDROID_HOME=${ANDROID_SDK_ROOT} \
    ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT} \
  JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
  PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    unzip \
    xz-utils \
    zip \
    openjdk-17-jdk \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Android command-line tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
      -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

# SDK packages aligned with CI (API 30 emulator smoke) and Flutter Android builds
RUN yes | sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --licenses \
    && sdkmanager --sdk_root=${ANDROID_SDK_ROOT} \
      "platform-tools" \
      "platforms;android-34" \
      "build-tools;34.0.0" \
      "emulator" \
      "system-images;android-30;google_apis;x86_64"

# Non-root user for devcontainer remoteUser
RUN useradd -m -s /bin/bash -u 1000 vscode 2>/dev/null || true \
    && chown -R vscode:vscode ${ANDROID_SDK_ROOT}

USER vscode
WORKDIR /workspace

RUN flutter config --no-analytics \
    && flutter precache --android \
    && yes | flutter doctor --android-licenses 2>/dev/null || true
