#include "saber/funcs/impl/cuda/saber_slice.h"

namespace anakin{

namespace saber{

template <typename dtype>
__global__ void slice_impl_cuda(const int nthreads, const dtype* in_data,
                                const int num_slices, const int slice_size,
                                const int in_slice_axis_size, const int out_slice_axis_size,
                                const int offset_slice_axis, dtype* out_data) {
    CUDA_KERNEL_LOOP(index, nthreads) {
        const int total_slice_size = slice_size * out_slice_axis_size;
        const int slice_num = index / total_slice_size;
        const int slice_index = index % total_slice_size;
        const int in_index = slice_index +
                                 (slice_num * in_slice_axis_size + offset_slice_axis) * slice_size;
        out_data[index] = in_data[in_index];
    }
}


template <DataType OpDtype,
            DataType inDtype,
            DataType outDtype,
            typename LayOutType_op,
            typename LayOutType_in,
            typename LayOutType_out>
SaberStatus SaberSlice<NV, OpDtype, inDtype, outDtype,\
    LayOutType_op, LayOutType_in, LayOutType_out>::dispatch(\
    const std::vector<DataTensor_in *>& inputs, \
    std::vector<DataTensor_out *>& outputs, \
    SliceParam<OpTensor>& param) {

    cudaStream_t stream = this->_ctx.get_compute_stream();
    //! inputs only has one tensor
    Shape shape_in = inputs[0]->valid_shape();

    int output_size = outputs.size();

#if 0 //! shared buffer
    outputs[0]->share_sub_buffer(*inputs[0], outputs[0]->valid_shape(), \
        inputs[0]->offset());
    for (int i = 1; i < output_size; ++i) {
        Shape offset = inputs[0]->offset();
        offset[param.axis] += param.slice_points[i - 1];
        outputs[i]->share_sub_buffer(*inputs[0], outputs[i]->valid_shape(), offset);
    }

#endif

#if 1 //! deep copy
    //! if output only has one tensor, then shared the memory buffer
    if (output_size == 1) {
        outputs[0]->share_from(*inputs[0]);
        return SaberSuccess;
    }

    int offset_slice_axis = 0;
    const OpDataType* in_data = inputs[0]->data();
    const int in_slice_axis_size = shape_in[param.axis];
    for (int i = 0; i < output_size; ++i) {
        OpDataType* out_data = outputs[i]->mutable_data();
        const int out_slice_axis_size = outputs[i]->valid_shape()[param.axis];
        const int out_slice_size = out_slice_axis_size * _slice_size;
        const int nthreads = out_slice_size * _slice_num;
        slice_impl_cuda<OpDataType><<<CUDA_GET_BLOCKS(nthreads), CUDA_NUM_THREADS, 0, stream>>>(
                nthreads, in_data, _slice_num, _slice_size,
                        in_slice_axis_size, out_slice_axis_size, offset_slice_axis, out_data);
        offset_slice_axis += out_slice_axis_size;
        //outputs[i]->record_event(stream);
    }
#endif
    return SaberSuccess;

}

} //namespace anakin

} //namespace anakin
