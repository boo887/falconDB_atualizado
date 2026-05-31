#!/bin/bash

cd "$(dirname "$0")/.."

DNS=(dn0s1 dn0s2 dn0s3 dn1s1 dn1s2 dn1s3 dn2s1 dn2s2 dn2s3)
SHARDS=(dn0 dn1 dn2)
DBPATH=/app/DBdata

get_files() {
  podman exec $1 sh -c "find $DBPATH -name '*.json' -exec md5sum {} \; 2>/dev/null | sort" | tr '\n' ' '
}

get_content() {
  podman exec $1 sh -c "find $DBPATH -name '*.json' -exec cat {} \;" 2>/dev/null
}

echo "=== snapshot before ==="
declare -A BEFORE
for dn in "${DNS[@]}"; do
  BEFORE[$dn]=$(get_files $dn)
done

echo ""
echo "=== executing: $@ ==="
"$@"
echo ""

echo "=== snapshot after ==="
declare -A CHANGED_SHARDS
for shard in "${SHARDS[@]}"; do
  s1=$(get_files ${shard}s1)
  s2=$(get_files ${shard}s2)
  s3=$(get_files ${shard}s3)
  if [ "${BEFORE[${shard}s1]}" != "$s1" ] || \
     [ "${BEFORE[${shard}s2]}" != "$s2" ] || \
     [ "${BEFORE[${shard}s3]}" != "$s3" ]; then
    echo "  $shard: CHANGED"
    CHANGED_SHARDS[$shard]=1
  else
    echo "  $shard: unchanged"
  fi
done

# Detect if this was a delete (files disappeared from the changed shard)
IS_DELETE=false
for shard in "${!CHANGED_SHARDS[@]}"; do
  after=$(get_files ${shard}s1)
  before="${BEFORE[${shard}s1]}"
  # Count files: if fewer after than before => delete
  before_count=$(echo "$before" | grep -o '\.json' | wc -l)
  after_count=$(echo "$after" | grep -o '\.json' | wc -l)
  if [ "$after_count" -lt "$before_count" ]; then
    IS_DELETE=true
  fi
done

echo ""
if $IS_DELETE; then
  echo "=== delete check ==="
  changed_count=${#CHANGED_SHARDS[@]}
  if [ "$changed_count" -eq 1 ]; then
    shard="${!CHANGED_SHARDS[@]}"
    echo "  [PASS] file removed from exactly 1 shard ($shard) — other shards untouched"
  elif [ "$changed_count" -eq 0 ]; then
    echo "  [FAIL] no shard changed — file was not deleted"
  else
    echo "  [FAIL] $changed_count shards changed — delete should affect exactly 1 shard"
  fi
fi

echo ""
echo "=== consistency check per shard ==="
for shard in "${SHARDS[@]}"; do
  echo ""
  echo "-- Shard $shard --"
  C1=$(get_content ${shard}s1)
  C2=$(get_content ${shard}s2)
  C3=$(get_content ${shard}s3)
  if [ "$C1" = "$C2" ] && [ "$C2" = "$C3" ]; then
    echo "  [PASS] all replicas consistent"
    if [ -n "${CHANGED_SHARDS[$shard]}" ] && ! $IS_DELETE && [ -n "$C1" ]; then
      echo "  content: $C1"
    fi
  else
    echo "  [FAIL] replicas inconsistent!"
    echo "  ${shard}s1: $C1"
    echo "  ${shard}s2: $C2"
    echo "  ${shard}s3: $C3"
  fi
done
