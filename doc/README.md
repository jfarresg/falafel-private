# Falafel v2 document <!-- omit in toc -->
last update: Dec 5, 2024

- [Quick Usage](#quick-usage)
  - [configs](#configs)
  - [expected behavior](#expected-behavior)

**for details...**　→ [document.md](documents.md)


## Quick Usage
### configs
under construction
<br>

### expected behavior
This(↓) is the output and waveform from running `test_falafel` @commit [1ac4714](https://github.com/jfarresg/falafel-private/tree/1ac471434f5dd88dc25423d4c38ad998182ebedb)

- waveform <br>
  [expected waveform](dump_241205.fst)

- output <br>
    ```
    ---------------------- Start first fit test ----------------------
    falafel/dev/test_falafel.py:46: DeprecationWarning: Setting values on handles using the ``dut.handle = value`` syntax is deprecated. Instead use the ``handle.value = value`` syntax
    dut.falafel_config_i = packed_value
    Sent request to allocate
    Granted lock
    Granted cas
    -----Start allocation-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2000
    Addr: 2000, Size: 500, Next Addr: 3000
    -----finish loading / finding fit-----
    -----Granted updating the allocated block-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 200, Next Addr: 0
    Addr: 2000, Size: 500, Next Addr: 3000
    -----Granted creating the new block-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 200, Next Addr: 0
    Addr: 716, Size: 100, Next Addr: 2000
    Addr: 2000, Size: 500, Next Addr: 3000
    -----Granted adjusting the link-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 716
    Addr: 500, Size: 200, Next Addr: 0
    Addr: 716, Size: 100, Next Addr: 2000
    Addr: 2000, Size: 500, Next Addr: 3000
    Granted release lock
    905.00ns INFO     cocotb.regression                  test_falafel_alloc_first_fit passed
    905.00ns INFO     cocotb.regression                  running test_falafel_alloc_best_fit (2/5)
    ---------------------- Start best fit test ----------------------
    falafel/dev/test_falafel.py:154: DeprecationWarning: Setting values on handles using the ``dut.handle = value`` syntax is deprecated. Instead use the ``handle.value = value`` syntax
    dut.falafel_config_i = packed_value
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2000
    Addr: 2000, Size: 299, Next Addr: 0
    Sent request to allocate
    Granted lock
    Granted cas
    -----Start allocation-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2000
    Addr: 2000, Size: 299, Next Addr: 0
    -----finish loading / finding fit-----
    -----Granted updating the allocated block-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2000
    Addr: 2000, Size: 200, Next Addr: 0
    -----Granted creating the new block-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2000
    Addr: 2000, Size: 200, Next Addr: 0
    Addr: 2216, Size: 99, Next Addr: 0
    -----Granted adjusting the link-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2216
    Addr: 2000, Size: 200, Next Addr: 0
    Addr: 2216, Size: 99, Next Addr: 0
    Granted release lock
    1900.00ns INFO     cocotb.regression                  test_falafel_alloc_best_fit passed
    1900.00ns INFO     cocotb.regression                  running test_falafel_free_merge_right (3/5)
    ------------------ Start free merge right test ------------------
    falafel/dev/test_falafel.py:262: DeprecationWarning: Setting values on handles using the ``dut.handle = value`` syntax is deprecated. Instead use the ``handle.value = value`` syntax
    dut.falafel_config_i = packed_value
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2216
    Addr: 2000, Size: 200, Next Addr: 0
    Addr: 2216, Size: 83, Next Addr: 0
    Sent request to free
    Granted lock
    Granted cas
    -----Start allocation-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2216
    Addr: 2000, Size: 200, Next Addr: 0
    Addr: 2216, Size: 83, Next Addr: 0
    -----finding block to free-----
    -----Granted adjusting the link-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 300, Next Addr: 2000
    Addr: 2000, Size: 299, Next Addr: 0
    Addr: 2216, Size: 83, Next Addr: 0
    Granted release lock
    2885.00ns INFO     cocotb.regression                  test_falafel_free_merge_right passed
    2885.00ns INFO     cocotb.regression                  running test_falafel_free_merge_left (4/5)
    ------------------ Start free merge left test ------------------
    falafel/dev/test_falafel.py:369: DeprecationWarning: Setting values on handles using the ``dut.handle = value`` syntax is deprecated. Instead use the ``handle.value = value`` syntax
    dut.falafel_config_i = packed_value
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 284, Next Addr: 2000
    Addr: 800, Size: 500, Next Addr: 0
    Addr: 2000, Size: 299, Next Addr: 0
    Sent request to free
    Granted lock
    Granted cas
    -----Start freeing-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 284, Next Addr: 2000
    Addr: 800, Size: 500, Next Addr: 0
    Addr: 2000, Size: 299, Next Addr: 0
    -----finding block to free-----
    -----Granted creating a block-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 800, Next Addr: 2000
    Addr: 800, Size: 500, Next Addr: 0
    Addr: 2000, Size: 299, Next Addr: 0
    Granted release lock
    3730.00ns INFO     cocotb.regression                  test_falafel_free_merge_left passed
    3730.00ns INFO     cocotb.regression                  running test_falafel_free_merge_both_sides (5/5)
    ---------------- Start free merge both sides test ----------------
    falafel/dev/test_falafel.py:459: DeprecationWarning: Setting values on handles using the ``dut.handle = value`` syntax is deprecated. Instead use the ``handle.value = value`` syntax
    dut.falafel_config_i = packed_value
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 284, Next Addr: 2000
    Addr: 800, Size: 1184, Next Addr: 2000
    Addr: 2000, Size: 299, Next Addr: 0
    Sent request to free
    Granted lock
    Granted cas
    -----Start freeing-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 284, Next Addr: 2000
    Addr: 800, Size: 1184, Next Addr: 2000
    Addr: 2000, Size: 299, Next Addr: 0
    -----finding block to free-----
    -----Granted creating a block-----
    LinkedList contents:
    Addr: 16, Size: 160, Next Addr: 300
    Addr: 300, Size: 100, Next Addr: 500
    Addr: 500, Size: 1799, Next Addr: 0
    Addr: 800, Size: 1184, Next Addr: 2000
    Addr: 2000, Size: 299, Next Addr: 0
    Granted release lock
    4655.01ns INFO     cocotb.regression                  test_falafel_free_merge_both_sides passed
    4655.01ns INFO     cocotb.regression                  *********************************************************************************************************
                                                            ** TEST                                             STATUS  SIM TIME (ns)  REAL TIME (s)  RATIO (ns/s) **
                                                            *********************************************************************************************************
                                                            ** test_falafel.test_falafel_alloc_first_fit         PASS         905.00           0.03      34167.60  **
                                                            ** test_falafel.test_falafel_alloc_best_fit          PASS         995.00           0.04      25424.23  **
                                                            ** test_falafel.test_falafel_free_merge_right        PASS         985.00           0.03      28738.33  **
                                                            ** test_falafel.test_falafel_free_merge_left         PASS         845.00           0.02      34687.46  **
                                                            ** test_falafel.test_falafel_free_merge_both_sides   PASS         925.00           0.04      23917.54  **
                                                            *********************************************************************************************************
                                                            ** TESTS=5 PASS=5 FAIL=0 SKIP=0                                  4655.01           0.28      16727.86  **
                                                            *********************************************************************************************************
                                                            
    - :0: Verilog $finish
    ```

