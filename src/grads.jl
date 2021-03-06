import NNlib: ∇conv_data, ∇conv_filter

function cudnn_convolution_backward_bias(t::Tensor{T,N}) where {T,N}
  ptr = Ref(Ptr{Cvoid}())
  atg_cudnn_convolution_backward_bias(ptr, t.ptr)
  Tensor{T,N}(ptr[], on(t))
end

const ∇conv_bias = cudnn_convolution_backward_bias

function ∇conv_data(dy::AbstractArray, w::Tensor{T},
                    cdims::DenseConvDims{M,K,C_in,C_out,S,P,D,F};
                    groups = 1,
                    benchmark = 0,
                    deterministic = 0) where {M,K,C_in,C_out,S,P,D,F, T}

  dy_ = tensor(dy, dev = on(w))
  ptr = Ref(Ptr{Cvoid}())
  padding          = [P[1];P[3]]
  stride           = collect(S)
  dilation         = collect(D)

  s = reverse([NNlib.input_size(cdims)...,
               NNlib.channels_in(cdims),
               size(dy_, ndims(dy_))])

  atg_cudnn_convolution_backward_input(ptr,
                                       s, length(s),
                                       dy_.ptr, w.ptr,
                                       padding,  length(padding),
                                       stride,   length(stride),
                                       dilation, length(dilation),
                                       groups, benchmark, deterministic)
  Tensor{T,ndims(dy_)}(ptr[], on(dy_))
end

function ∇conv_filter(w::Tensor{T}, dy::AbstractArray{T},
                      cdims::DenseConvDims{M,K,C_in,C_out,S,P,D,F};
                      groups = 1,
                      benchmark = 0,
                      deterministic = 0) where {M,K,C_in,C_out,S,P,D,F, T}

  dy_ = tensor(dy, dev = on(w))
  ptr = Ref(Ptr{Cvoid}())
  padding          = [P[1];P[3]]
  stride           = collect(S)
  dilation         = collect(D)

  s = reverse([NNlib.kernel_size(cdims)...,
               NNlib.channels_in(cdims),
               NNlib.channels_out(cdims)])

  atg_cudnn_convolution_backward_weight(ptr,
                                        s, length(s),
                                        dy_.ptr, w.ptr,
                                        padding,  length(padding),
                                        stride,   length(stride),
                                        dilation, length(dilation),
                                        groups, benchmark, deterministic)

  Tensor{T,ndims(dy_)}(ptr[], on(dy_))
end

function NNlib.∇maxpool(dy::Tensor{T,M}, y::Tensor{T,M}, x::Tensor{T,M},
                        pdims::PoolDims{N,K,S,P,D};
                        ceil_mode = 0,
                        indices::Tensor) where {N,K,S,P,D, T,M}

  ptr = Ref(Ptr{Cvoid}())
  kernel = collect(NNlib.kernel_size(pdims))
  stride = collect(S)
  padding = [P[1];P[3]]

  atg_max_pool2d_with_indices_backward(ptr, dy.ptr, x.ptr,
                          kernel, length(kernel),
                          stride, length(stride),
                          padding, length(padding),
                          ceil_mode,
                          indices.ptr
  )

  Tensor{T,N}(ptr[], on(x))
end

@adjoint function _maxpool(t::Tensor, pdims::PoolDims; ceil_mode = 0)
  op, inds = _maxpool_with_inds(t, pdims, ceil_mode = ceil_mode)
  op, Δ -> begin
    ∇maxpool(Δ, y, x, pdims, ceil_mode = ceil_mode, indices = inds)
  end
end

function NNlib.∇meanpool(dy::Tensor{T,M}, y::Tensor{T,M}, x::Tensor{T,M},
                         pdims::PoolDims{N,K,S,P,D};
                         ceil_mode = 0,
                         count_include_pad = 1,
                         divisor_override = 1) where {N,K,S,P,D, T,M}

  ptr = Ref(Ptr{Cvoid}())
  kernel = collect(NNlib.kernel_size(pdims))
  stride = collect(S)
  padding = [P[1];P[3]]

  atg_avg_pool2d_backward(ptr,
                          dy.ptr, x.ptr,
                          kernel, length(kernel),
                          stride, length(stride),
                          padding, length(padding),
                          ceil_mode,
                          count_include_pad,
                          divisor_override)

  Tensor{T,M}(ptr[], on(x))
end

function ∇sigmoid(dy::AbstractArray, t::Tensor{T,N}) where {T,N}
  ptr = Ref(Ptr{Cvoid}())

  dy_ = tensor(dy, dev = on(t))
  atg_sigmoid_backward(ptr, dy_.ptr, t.ptr)
  Tensor{T,N}(ptr[], on(t))
end

@adjoint function NNlib.sigmoid(t::Tensor)
  x = sigmoid(t)
  x, Δ -> (∇sigmoid(Δ, x),)
end
