#!/bin/bash

PORT=9090
SERVER="./mini_serv"

PASS=0
FAIL=0

cleanup()
{
    kill "$SERVER_PID" 2>/dev/null
    kill "$C1" 2>/dev/null
    kill "$C2" 2>/dev/null
    kill "$C3" 2>/dev/null
    rm -f /tmp/mini_*
}

trap cleanup EXIT

pass()
{
    echo -e "\033[32m[PASS]\033[0m $1"
    PASS=$((PASS + 1))
}

fail()
{
    echo -e "\033[31m[FAIL]\033[0m $1"
    FAIL=$((FAIL + 1))
}

echo "======================================"
echo "       mini_serv test suite"
echo "======================================"

# ======================================
# 1. Argument test
# ======================================

echo
echo "== Argument tests =="

OUTPUT=$(./mini_serv 2>&1)
STATUS=$?

if [ "$STATUS" -eq 1 ] && [ "$OUTPUT" = "Wrong number of arguments" ]; then
    pass "no arguments"
else
    fail "no arguments"
    echo "Got: [$OUTPUT]"
fi

OUTPUT=$(./mini_serv 9090 extra 2>&1)
STATUS=$?

if [ "$STATUS" -eq 1 ] && [ "$OUTPUT" = "Wrong number of arguments" ]; then
    pass "too many arguments"
else
    fail "too many arguments"
    echo "Got: [$OUTPUT]"
fi


# ======================================
# 2. Start server
# ======================================

echo
echo "== Starting server =="

$SERVER "$PORT" >/tmp/mini_server.out 2>/tmp/mini_server.err &
SERVER_PID=$!

sleep 0.3

if kill -0 "$SERVER_PID" 2>/dev/null; then
    pass "server starts"
else
    fail "server starts"
    cat /tmp/mini_server.err
    exit 1
fi


# ======================================
# 3. Client 0
# ======================================

echo
echo "== Client tests =="

rm -f /tmp/mini_c1

nc 127.0.0.1 "$PORT" > /tmp/mini_c1 &
C1=$!

sleep 0.5

echo "--- client 0 output ---"
cat /tmp/mini_c1
echo "-----------------------"

if grep -Fq "server: client 0 just arrived" /tmp/mini_c1; then
    pass "client 0 gets ID 0"
else
    fail "client 0 gets ID 0"
fi


# ======================================
# 4. Client 1
# ======================================

rm -f /tmp/mini_c2

nc 127.0.0.1 "$PORT" > /tmp/mini_c2 &
C2=$!

sleep 0.5

echo "--- client 0 output ---"
cat /tmp/mini_c1
echo "--- client 1 output ---"
cat /tmp/mini_c2
echo "-----------------------"

if grep -Fq "server: client 1 just arrived" /tmp/mini_c1 &&
   grep -Fq "server: client 1 just arrived" /tmp/mini_c2
then
    pass "client 1 arrival sent to both clients"
else
    fail "client 1 arrival sent to both clients"
fi


# ======================================
# 5. Send message from client 0
# ======================================

echo
echo "== Message test =="

printf "hello\n" | nc 127.0.0.1 "$PORT" >/tmp/mini_sender &

SENDER=$!

sleep 0.5

echo "--- client 0 ---"
cat /tmp/mini_c1

echo "--- client 1 ---"
cat /tmp/mini_c2

echo "-----------------------"

if grep -Fq "client 2: hello" /tmp/mini_c1 &&
   grep -Fq "client 2: hello" /tmp/mini_c2
then
    pass "message broadcast"
else
    fail "message broadcast"
fi

wait "$SENDER" 2>/dev/null


# ======================================
# 6. Multiple lines
# ======================================

echo
echo "== Multiple lines =="

printf "one\ntwo\nthree\n" | nc 127.0.0.1 "$PORT" >/tmp/mini_sender2 &

SENDER2=$!

sleep 0.5

echo "--- received ---"
cat /tmp/mini_c1
echo "---------------"

if grep -Fq "client 3: one" /tmp/mini_c1 &&
   grep -Fq "client 3: two" /tmp/mini_c1 &&
   grep -Fq "client 3: three" /tmp/mini_c1
then
    pass "multiple lines"
else
    fail "multiple lines"
fi

wait "$SENDER2" 2>/dev/null


# ======================================
# 7. Disconnect
# ======================================

echo
echo "== Disconnect test =="

kill "$C2" 2>/dev/null
wait "$C2" 2>/dev/null

sleep 0.5

echo "--- client 0 ---"
cat /tmp/mini_c1
echo "---------------"

if grep -Fq "server: client 1 just left" /tmp/mini_c1; then
    pass "disconnect notification"
else
    fail "disconnect notification"
fi


# ======================================
# 8. Server still alive
# ======================================

if kill -0 "$SERVER_PID" 2>/dev/null; then
    pass "server still alive"
else
    fail "server crashed"
fi


# ======================================
# Result
# ======================================

echo
echo "======================================"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "======================================"

if [ "$FAIL" -eq 0 ]; then
    echo -e "\033[32mALL TESTS PASSED\033[0m"
else
    echo -e "\033[31mSOME TESTS FAILED\033[0m"
fi
