ARG BASE_IMAGE=ghcr.io/ublue-os/bluefin
ARG BASE_TAG=stable

FROM ${BASE_IMAGE}:${BASE_TAG}

ARG BUILD_PROFILE=generic-x86_64
ARG IMAGE_NAME=purplefin
ARG IMAGE_VENDOR=declarative-dale
ARG PURPLEFIN_DELL_IPU7_KERNEL_EVR=
ARG PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED=0

LABEL org.opencontainers.image.title="Purplefin"
LABEL org.opencontainers.image.description="A custom Bluefin image with selectable hardware profiles"
LABEL org.opencontainers.image.vendor="${IMAGE_VENDOR}"
LABEL org.opencontainers.image.source="https://github.com/declarative-dale/purplefin"
LABEL org.opencontainers.image.base.name="${BASE_IMAGE}:${BASE_TAG}"

COPY system_files/ /
COPY manifests/Brewfile /usr/share/purplefin/manifests/Brewfile
COPY manifests/flatpaks.preinstall /usr/share/flatpak/preinstall.d/purplefin.preinstall
COPY build_files/ /tmp/purplefin-build/
COPY profile_files/ /tmp/purplefin-profile-files/

RUN PURPLEFIN_DELL_IPU7_KERNEL_EVR="${PURPLEFIN_DELL_IPU7_KERNEL_EVR}" \
    PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED="${PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED}" \
    /tmp/purplefin-build/build.sh "${BUILD_PROFILE}" && \
    rm -rf /tmp/purplefin-build /tmp/purplefin-profile-files && \
    bootc container lint && \
    ostree container commit
