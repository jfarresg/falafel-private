# dev log
- Nov 21:  moved the contents of the dev-core branch of [hw-allocator](https://github.com/takeshiho0531/hw-allocator) to the v2-dev branch of [falafel-private](https://github.com/takeshiho0531/falafel-private) 🙌
- Nov 22:  <br><span style="color: magenta;"><u>**falafel v2 supports first fit**</u></span> @[8305eb2a](https://github.com/jfarresg/falafel-private/tree/8305eb2a7a5b417a713e5f56754c76eb9fdf5a59) <br>
<span style="color: magenta;"><u>**falafel v2 supports best fit**</u></span> @[afb19ab7](https://github.com/jfarresg/falafel-private/tree/afb19ab7a4f71eb5533b0bd1b2315c628715af37)
- Nov 28: implement a simple free logic @[f20cd650](https://github.com/jfarresg/falafel-private/tree/f20cd65041cb26238f44287c8eb97e2ed6dab910)
- Nov 29: implement a feature to merge blocks when freeing, if the block is next to the one on the right @[15af0dda](https://github.com/jfarresg/falafel-private/tree/15af0dda0423f4fe7cc4ffe8d0bd92d0672fcfe0)
- Nov 30: <br> implement a feature to merge blocks when freeing, if the block is next to the one on the left @[2003be1c](https://github.com/jfarresg/falafel-private/tree/2003be1c5972101a479c7aad083bac49d947aa1c) <br>
<span style="color: magenta;"><u>**falafel v2 now supports a feature to merge blocks when freeing**</u></span> if the free blocks are next to each other @[db109d22](https://github.com/jfarresg/falafel-private/tree/db109d22db36fe63487d010262a3fcaa1756f88e)  
- Dec 5: integrated the *falafel_input_arbiter* and *falafel_fifo* used in falafel v1
- Dec 8: allocation requests can now be processed within the cohort under bare-metal conditions (with the mmu deactivated); enabling `swi_gc_wf_bench.c` to run (spsc) @[a30decc](https://github.com/takeshiho0531/falafel-private/tree/c5dfd09a261dcbb735852c8c219cec16338f4202)
- Dec 9: allocation requests can now be processed within with the mmu activated; enabling `swi_gc_wf_bench.c` to run (spsc) @[c5dfd09](https://github.com/takeshiho0531/falafel-private/tree/c5dfd09a261dcbb735852c8c219cec16338f4202) <br>/ `cohort-private` @[24b580d
](https://github.com/pengwing-project/cohort-private/commit/24b580d0831a93e1a45612758924258fdd29164e)

- Dec 18: succeeded in making falafelv2 work on fpga(an allocation request); enabling `swi_gc_wf_bench.c` to run (spsc) @[8e65fa7](https://github.com/takeshiho0531/falafel-private/tree/8e65fa766a2c0dce988f6193a429acf09c33fcb2) <br>/ `cohort-private` @[bd7aa96
](https://github.com/pengwing-project/cohort-private/tree/bd7aa9658fa7ea0409b6d1b92f30a312503eddf5)

- Dec 26: succeeded in making falafelv2 work on fpga(an allocation requests & a free request); enabling `swi_gc_wf_bench.c` to run (spsc) @[5fe80cc](https://github.com/takeshiho0531/falafel-private/tree/5fe80cc6501b2f6427a16aa2aee85f1ce0f62ae5) <br>/ `cohort-private` @[c9bf120
](https://github.com/pengwing-project/cohort-private/tree/c9bf12084d516de533e633204fb6377b2492169c)