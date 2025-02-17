// RUN: triton-opt %s -split-input-file -tritongpu-optimize-thread-locality -canonicalize | FileCheck %s

// CHECK-LABEL: negative_zero_accumulator
// CHECK: %[[INIT_ARG:.*]] = arith.constant dense<0.000000e+00>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[INIT_ARG]]) -> {{.*}}
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK: tt.reshape %[[LOAD]] {allow_reorder = true} : {{.*}} -> tensor<{{32x32x4xf32.*}}
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.addf
// CHECK: arith.addf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: tt.store {{%.*}}, %[[CVT_OUTPUT]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @negative_zero_accumulator(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<-0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.addf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.addf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: positive_zero_accumulator
// CHECK: %[[CST:.*]] = arith.constant dense<0.000000e+00>
// CHECK-NEXT: %[[CST1:.*]] = arith.constant dense<0.000000e+00>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST1]]) -> {{.*}}
// CHECK: tt.load
// CHECK: tt.reshape
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.addf
// CHECK: arith.addf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: arith.addf %[[CVT_OUTPUT]], %[[CST]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @positive_zero_accumulator(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.addf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.addf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: slice_layout
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK-NEXT: "tt.reduce"(%[[LOAD]]) <{axis = 1 : i32}>
// CHECK: arith.addf
// CHECK: arith.addf
// CHECK-NEXT: scf.yield
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[LOOP_OUTPUT]]
#blocked3d = #triton_gpu.blocked<{sizePerThread = [1, 4, 1], threadsPerWarp = [1, 32, 1], warpsPerCTA = [4, 1, 1], order = [2, 1, 0], CTAsPerCGA = [1, 1, 1], CTASplitNum = [1, 1, 1], CTAOrder = [0, 1, 2]}>
#slice2d = #triton_gpu.slice<{dim = 2, parent = #blocked3d}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @slice_layout(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #slice2d> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #slice2d}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #slice2d}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #slice2d}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #slice2d}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #slice2d}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #slice2d}>>) -> tensor<1x128xi32, #slice2d>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #slice2d>) -> tensor<32x128xi32, #slice2d>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #slice2d>, tensor<32x128xi32, #slice2d>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #slice2d>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.addf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #slice2d>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #slice2d}>>
      %35 = arith.addf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #slice2d}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #slice2d}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #slice2d}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: mma_layout
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK-NEXT: "tt.reduce"(%[[LOAD]]) <{axis = 1 : i32}>
// CHECK: arith.addf
// CHECK: arith.addf
// CHECK-NEXT: scf.yield
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[LOOP_OUTPUT]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 4], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#mma = #triton_gpu.mma<{versionMajor = 2, warpsPerCTA = [4, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @mma_layout(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #mma> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #mma}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #mma}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #mma}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #mma}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #mma}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #mma}>>) -> tensor<1x128xi32, #mma>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #mma>) -> tensor<32x128xi32, #mma>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #mma>, tensor<32x128xi32, #mma>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #mma>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.addf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #mma>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #mma}>>
      %35 = arith.addf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #mma}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #mma}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #mma}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: max_reduce
// CHECK: %[[INIT_ARG:.*]] = arith.constant dense<0xFF800000>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[INIT_ARG]]) -> {{.*}}
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK: tt.reshape %[[LOAD]] {allow_reorder = true} : {{.*}} -> tensor<{{32x32x4xf32.*}}
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.maximumf
// CHECK: arith.maximumf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: arith.maximumf
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: tt.store {{%.*}}, %[[CVT_OUTPUT]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @max_reduce(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0xFF800000> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.maximumf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.maximumf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: max_reduce_zero_int_accumulator
// CHECK: %[[CST:.*]] = arith.constant dense<0.000000e+00>
// CHECK-NEXT: %[[CST1:.*]] = arith.constant dense<0xFF800000>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST1]]) -> {{.*}}
// CHECK: tt.load
// CHECK: tt.reshape
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.maximumf
// CHECK: arith.maximumf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: arith.maximumf
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: arith.maximumf %[[CVT_OUTPUT]], %[[CST]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @max_reduce_zero_int_accumulator(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.maximumf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.maximumf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: min_reduce
// CHECK: %[[CST:.*]] = arith.constant dense<0x7F800000>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST]]) -> {{.*}}
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK: tt.reshape %[[LOAD]] {allow_reorder = true} : {{.*}} -> tensor<{{32x32x4xf32.*}}
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.minimumf
// CHECK: arith.minimumf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: arith.minimumf
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: tt.store {{%.*}}, %[[CVT_OUTPUT]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @min_reduce(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0x7F800000> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.minimumf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.minimumf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: min_reduce_zero_int_accumulator
// CHECK: %[[CST:.*]] = arith.constant dense<0.000000e+00>
// CHECK-NEXT: %[[CST1:.*]] = arith.constant dense<0x7F800000>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST1]]) -> {{.*}}
// CHECK: tt.load
// CHECK: tt.reshape
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.minimumf
// CHECK: arith.minimumf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: arith.minimumf
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: arith.minimumf %[[CVT_OUTPUT]], %[[CST]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @min_reduce_zero_int_accumulator(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.minimumf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.minimumf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: mul_reduce
// CHECK: %[[CST:.*]] = arith.constant dense<1.000000e+00>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST]]) -> {{.*}}
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK: tt.reshape %[[LOAD]] {allow_reorder = true} : {{.*}} -> tensor<{{32x32x4xf32.*}}
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.mulf
// CHECK: arith.mulf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: arith.mulf
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: tt.store {{%.*}}, %[[CVT_OUTPUT]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @mul_reduce(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<1.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.mulf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.mulf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}

// -----

// CHECK-LABEL: mul_reduce_zero_int_accumulator
// CHECK: %[[CST:.*]] = arith.constant dense
// CHECK-NEXT: %[[CST1:.*]] = arith.constant dense<1.000000e+00>
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST1]]) -> {{.*}}
// CHECK: tt.load
// CHECK: tt.reshape
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"({{%.*}}) <{axis = 2 : i32}>
// CHECK: arith.mulf
// CHECK: arith.mulf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
// CHECK: %[[FINAL_REDUCE:.*]] = "tt.reduce"(%[[LOOP_OUTPUT]]) <{axis = 1 : i32}>
// CHECK: arith.mulf
// CHECK: %[[CVT_OUTPUT:.*]] = triton_gpu.convert_layout %[[FINAL_REDUCE]]
// CHECK: arith.mulf %[[CVT_OUTPUT]], %[[CST]]
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @mul_reduce_zero_int_accumulator(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%33) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.mulf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.mulf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}


// -----

// CHECK-LABEL: remains_unchanged
// CHECK: %[[CST:.*]] = arith.constant dense
// CHECK: %[[LOOP_OUTPUT:.*]] = scf.for {{.*}} iter_args(%[[FOR_ARG:.*]] = %[[CST]]) -> {{.*}}
// CHECK: %[[LOAD:.*]] = tt.load
// CHECK: %[[MULF:.*]] = arith.mulf %[[LOAD]], %[[LOAD]]
// CHECK-NEXT: %[[REDUCE:.*]] = "tt.reduce"(%[[MULF]]) <{axis = 1 : i32}>
// CHECK: arith.maximumf
// CHECK: arith.maximumf %[[FOR_ARG]], %[[REDUCE]]
// CHECK-NEXT: scf.yield
#blocked = #triton_gpu.blocked<{sizePerThread = [1, 2], threadsPerWarp = [1, 32], warpsPerCTA = [4, 1], order = [1, 0], CTAsPerCGA = [1, 1], CTASplitNum = [1, 1], CTAOrder = [0, 1]}>
#blocked1 = #triton_gpu.blocked<{sizePerThread = [1], threadsPerWarp = [32], warpsPerCTA = [4], order = [0], CTAsPerCGA = [1], CTASplitNum = [1], CTAOrder = [0]}>
module attributes {"triton_gpu.compute-capability" = 80 : i32, "triton_gpu.num-ctas" = 1 : i32, "triton_gpu.num-warps" = 4 : i32, "triton_gpu.threads-per-warp" = 32 : i32} {
  tt.func public @remains_unchanged(
    %arg0: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg1: !tt.ptr<f32, 1> {tt.divisibility = 16 : i32},
    %arg2: i32 {tt.divisibility = 16 : i32, tt.max_divisibility = 8 : i32},
    %18: tensor<32x128x!tt.ptr<f32, 1>, #blocked> {tt.divisibility = 16 : i32},
    %11: i32 {tt.divisibility = 16 : i32},
    %25: tensor<32x!tt.ptr<f32, 1>, #blocked1> {tt.divisibility = 16 : i32}
    ) attributes {noinline = false} {
    %cst = arith.constant dense<0.000000e+00> : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    %c128_i32 = arith.constant 128 : i32
    %1 = tt.get_program_id y : i32
    %2 = tt.get_num_programs {axis = 1 : i32} : i32
    %12 = tt.make_range {end = 128 : i32, start = 0 : i32} : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
    %19 = scf.for %arg3 = %1 to %11 step %2 iter_args(%arg4 = %cst) -> (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>)  : i32 {
      %27 = arith.muli %arg3, %c128_i32 : i32
      %28 = tt.splat %27 : (i32) -> tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %29 = arith.addi %28, %12 : tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>
      %30 = tt.expand_dims %29 {axis = 0 : i32} : (tensor<128xi32, #triton_gpu.slice<{dim = 0, parent = #blocked}>>) -> tensor<1x128xi32, #blocked>
      %31 = tt.broadcast %30 : (tensor<1x128xi32, #blocked>) -> tensor<32x128xi32, #blocked>
      %32 = tt.addptr %18, %31 : tensor<32x128x!tt.ptr<f32, 1>, #blocked>, tensor<32x128xi32, #blocked>
      %33 = tt.load %32 {cache = 1 : i32, evict = 1 : i32, isVolatile = false} : tensor<32x128xf32, #blocked>
      %333 = arith.mulf %33, %33: tensor<32x128xf32, #blocked>
      %34 = "tt.reduce"(%333) <{axis = 1 : i32}> ({
      ^bb0(%arg5: f32, %arg6: f32):
        %36 = arith.maximumf %arg5, %arg6 : f32
        tt.reduce.return %36 : f32
      }) : (tensor<32x128xf32, #blocked>) -> tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      %35 = arith.maximumf %arg4, %34 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
      scf.yield %35 : tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>
    }
    %26 = triton_gpu.convert_layout %19 : (tensor<32xf32, #triton_gpu.slice<{dim = 1, parent = #blocked}>>) -> tensor<32xf32, #blocked1>
    tt.store %25, %26 {cache = 1 : i32, evict = 1 : i32} : tensor<32xf32, #blocked1>
    tt.return
  }
}
