#!/usr/bin/env python3
"""
Patch KJNodes to handle missing SageAttention CUDA/Triton kernels gracefully.

The PyPI sageattention package only has basic 'sageattn' function.
The CUDA int8 kernels require building from source with CUDA toolkit.
This patch wraps each conditional import with try/except to fall back to sageattn.
"""

import re

f = '/comfyui/custom_nodes/ComfyUI-KJNodes/nodes/model_optimization_nodes.py'
c = open(f).read()

# The imports in KJNodes are INSIDE the get_sage_func function like:
#     elif sage_attention == "sageattn_qk_int8_pv_fp16_cuda":
#         from sageattention import sageattn_qk_int8_pv_fp16_cuda
#         def sage_func(...):
#             return sageattn_qk_int8_pv_fp16_cuda(...)
#
# We need to wrap each import AND provide a fallback function

patches = [
    # sageattn_qk_int8_pv_fp16_cuda
    (
        'from sageattention import sageattn_qk_int8_pv_fp16_cuda',
        '''try:
            from sageattention import sageattn_qk_int8_pv_fp16_cuda
        except ImportError:
            from sageattention import sageattn
            def sageattn_qk_int8_pv_fp16_cuda(q, k, v, is_causal=False, attn_mask=None, pv_accum_dtype=None, tensor_layout="NHD"):
                return sageattn(q, k, v, is_causal=is_causal, attn_mask=attn_mask, tensor_layout=tensor_layout)'''
    ),
    # sageattn_qk_int8_pv_fp16_triton
    (
        'from sageattention import sageattn_qk_int8_pv_fp16_triton',
        '''try:
            from sageattention import sageattn_qk_int8_pv_fp16_triton
        except ImportError:
            from sageattention import sageattn
            def sageattn_qk_int8_pv_fp16_triton(q, k, v, is_causal=False, attn_mask=None, tensor_layout="NHD"):
                return sageattn(q, k, v, is_causal=is_causal, attn_mask=attn_mask, tensor_layout=tensor_layout)'''
    ),
    # sageattn_qk_int8_pv_fp8_cuda (used by both fp8_cuda and fp8_cuda++)
    (
        'from sageattention import sageattn_qk_int8_pv_fp8_cuda',
        '''try:
            from sageattention import sageattn_qk_int8_pv_fp8_cuda
        except ImportError:
            from sageattention import sageattn
            def sageattn_qk_int8_pv_fp8_cuda(q, k, v, is_causal=False, attn_mask=None, pv_accum_dtype=None, tensor_layout="NHD"):
                return sageattn(q, k, v, is_causal=is_causal, attn_mask=attn_mask, tensor_layout=tensor_layout)'''
    ),
]

patched_count = 0
for old, new in patches:
    if old in c:
        c = c.replace(old, new)
        patched_count += 1
        print(f'Patched: {old[:50]}...')

open(f, 'w').write(c)
print(f'KJNodes SageAttention patch complete: {patched_count} imports wrapped')