module gfm.image.bitmap;

import std.c.string, 
       std.math;

import gfm.common.alignedbuffer,
       gfm.common.memory,
       gfm.math.vector;

import gfm.image.image;

/**
    A Bitmap is a triplet of (base address + dimension + stride).
    Simplest possible image.
    Nothing to do with the .bmp format.
 */
struct Bitmap(T)
{
nothrow:
    public
    {
        alias T element_t;

        // create with owned memory
        this(vec2i dimension)
        {
            _data = alignedMalloc(dimension.x * dimension.y * T.sizeof, 64);
            _dimension = dimension;
            _stride = dimension.x * T.sizeof;
            _owned = true;
        }

        // create with existing data whose lifetime memory should exceed this
        this(T* data, vec2i dimension, ptrdiff_t stride)
        {
            _data = data;
            _dimension = dimension;
            _stride = stride;
            _owned = false;
        }

        this(T* data, vec2i dimension)
        {
            this(data, dimension, dimension.x * T.sizeof);
        }

        // create on a resused buffer whose lifetime should be greater than this
        this(AlignedBuffer!ubyte buffer, vec2i dimension)
        {
            size_t bytesNeeded = dimension.x * dimension.y * T.sizeof;
            buffer.resize(bytesNeeded);

            this(cast(T*)(buffer.ptr), dimension);
        }

        ~this()
        {
            if (_owned)
                alignedFree(_data);
        }

        // postblit needed to duplicate owned data
        this(this)
        {
            if (_owned)
            {
                size_t sizeInBytes = _dimension.x * _dimension.y * T.sizeof;
                void* oldData = _data;
                _data = alignedMalloc(sizeInBytes, 64);
                memcpy(_data, oldData, sizeInBytes);
            }
        }

        void opAssign(ref Bitmap other) pure nothrow
        {
            _data = other._data;
            _dimension = other._dimension;
            _stride = other._stride;
            _owned = other._owned;
        }

        // return a sub-bitmap
        Bitmap subImage(vec2i position, vec2i dimension)
        {
            assert(contains(position));
            assert(contains(position + dimension - 1));

            return Bitmap(address(position.x, position.y), dimension, _stride);
        }

        @property
        {
            T* ptr()
            {
                return cast(T*) _data;
            }

            const(T)* ptr() const
            {
                return cast(T*) _data;
            }

            vec2i dimension() const pure
            {
                return _dimension;
            }

            int width() const pure
            {
                return _dimension.x;
            }

            int height() const pure
            {
                return _dimension.y;
            }

        }

        T get(int i, int j) const pure
        {
            return *(address(i, j));
        }

        void set(int i, int j, T e)
        {
            *(address(i, j)) = e;
        }

        bool isDense() const pure
        {
            return (_stride == _dimension.x * T.sizeof);
        }

        bool contains(vec2i point)
        {
            return (cast(uint)(point.x) < cast(uint)(_dimension.x))
                && (cast(uint)(point.y) < cast(uint)(_dimension.y));
        }

        /// copy another Bitmap of same type and dimension
        void copy(Bitmap source)
        {
            assert(dimension == source.dimension);
            if (isDense() && source.isDense())
            {
                size_t bytes = dimension.x * dimension.y * T.sizeof;
                memcpy(_data, source._data, bytes);
            }
            else if(_stride == source._stride)
            {
                size_t bytes = _stride * dimension.y;
                memcpy(_data, source._data, bytes);
            }
            else
            {
                void* dest = _data;
                void* src = source._data;
                size_t lineSize = abs(_stride);

                for (size_t j = 0; j < dimension.y; ++j)
                {
                    memcpy(dest, src, lineSize);
                    dest += _stride;
                    src += source._stride;
                }
            }
        }
    }

    private
    {
        vec2i _dimension;
        void* _data;
        ptrdiff_t _stride;       // in bytes
        bool _owned;

        T* address(int i, int j) pure
        {
            return cast(T*)(_data + _stride * j + T.sizeof * i);
        }

        const(T)* address(int i, int j) const pure // :| where is inout(this)?
        {
            return cast(T*)(_data + _stride * j + T.sizeof * i);
        }
    }
}

static assert(isImage!(Bitmap!int));
static assert(isImage!(Bitmap!vec4ub));

unittest
{
    {
        int[] b;
        b.length = 10 * 10;
        b[] = 0;
        auto bitmap = Bitmap!int(b.ptr, vec2i(10, 5), 20 * int.sizeof);

        fillImage(bitmap, 1);
        assert(bitmap.dimension.x == 10);
        assert(bitmap.dimension.y == 5);

        for (int j = 0; j < 5; ++j)
            for (int i = 0; i < 10; ++i)
                assert(bitmap.get(i, j) == 1);

        for (int j = 0; j < 5; ++j)
            for (int i = 0; i < 10; ++i)
            {
                assert(b[i + (2 * j) * 10] == 1);
                assert(b[i + (2 * j + 1) * 10] == 0);
            }
    }
}
