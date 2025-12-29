# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bluefin-dx-surface-nvidia-open:42-20251019

# Copy system modifications
COPY system_files/ /

# [IM]MUTABLE /opt
# Uncomment the following line to make /opt immutable and be able to be used by the package manager.
RUN rm /opt && mkdir /opt

# MODIFICATIONS
# make modifications desired in your image and install packages by modifying the build.sh script
# the following RUN directive does all the things required to run "build.sh" as recommended.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
# LINTING
# Verify final image and contents are correct.
RUN bootc container lint
