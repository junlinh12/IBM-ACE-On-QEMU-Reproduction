# IBM-ACE-On-QEMU-Reproduction: build settings used by every build gate from G06 on.
# Reasons: docs/SAFETY_AUDIT.md, section "Build settings used from G06 on".
#
# Usage (PROJECT_ROOT must be set first):
#   PROJECT_ROOT=~/projects/IBM-ACE-On-QEMU-Reproduction
#   source "$PROJECT_ROOT/scripts/build_env.sh"

export ACE_DIR="$PROJECT_ROOT/build/ace/"                  # build output, outside the upstream checkout
export QEMU_SOURCE_DIR="$PROJECT_ROOT/build/qemu-source/"  # QEMU source, outside the checkout (A11)
export BR2_DL_DIR="$PROJECT_ROOT/build/dl"                 # Buildroot downloads, outside the submodule (A11)
export CARGO_HOME="$PROJECT_ROOT/build/cargo-home"         # crates, not the shared ~/.cargo (A11)
export BR2_JLEVEL=2                                        # Buildroot jobs (A1, needs patch 0001)
export OMP_NUM_THREADS=2                                   # GNU nproc reports 2 (A2, A3)
export CARGO_BUILD_JOBS=2                                  # cargo jobs (A4)
