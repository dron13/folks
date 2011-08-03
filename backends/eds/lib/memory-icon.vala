/*
 * Copyright (C) 2011 Philip Withnall
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *       Philip Withnall <philip@tecnocode.co.uk>
 */

using GLib;

/**
 * A wrapper around a blob of image data (with an associated content type) which
 * presents it as a {@link GLib.LoadableIcon}. This allows inlined avatars to be
 * returned as {@link GLib.LoadableIcon}s.
 *
 * @since UNRELEASED
 */
internal class Edsf.MemoryIcon : Object, Icon, LoadableIcon
{
  private uint8[] _image_data;
  private string _image_type;

  /**
   * Construct a new in-memory icon.
   *
   * @param image_type the content type of the image
   * @param image_data the binary data of the image
   * @since UNRELEASED
   */
  public MemoryIcon (string image_type, uint8[] image_data)
    {
      this._image_data = image_data;
      this._image_type = image_type;
    }

  /**
   * Decide whether two {@link MemoryIcon} instances are equal. This compares
   * their image types and image data, and only returns `true` if both are
   * identical.
   *
   * @param icon2 the {@link MemoryIcon} instance to compare against
   * @return `true` if the instances are equal, `false` otherwise
   * @since UNRELEASED
   */
  public bool equal (Icon icon2)
    {
      // This type check be taken care of by the interface wrapper.
      var icon = icon2 as MemoryIcon;
      assert (icon != null);

      return (this._image_data.length == icon._image_data.length &&
              this._image_type == icon._image_type &&
              Memory.cmp (this._image_data, icon._image_data,
                  this._image_data.length) == 0);
    }

  /**
   * Calculate a hash value of the image type and data, suitable for use as a
   * hash table key. This is not a cryptographic hash.
   *
   * @return hash value over the image type and data
   * @since UNRELEASED
   */
  public uint hash ()
    {
      /* Implementation based on g_str_hash() from GLib. We initialise the hash
       * with the g_str_hash() hash of the image type (which itself is
       * initialised with the magic number in GLib thought up by cleverer people
       * than myself), then add each byte in the image data to the hash value
       * by multiplying the hash value by 33 and adding the image data, as is
       * done on all bytes in g_str_hash(). I leave the rationale for this
       * calculation to the author of g_str_hash().
       *
       * Basically, this is just a nul-safe version of g_str_hash(). Which is
       * calculated over both the image type and image data. */
      uint hash = this._image_type.hash ();

      for (uint i = 0; i < this._image_data.length; i++)
        {
          hash = (hash << 5) + hash + this._image_data[i];
        }

      return hash;
    }

  /**
   * Build an input stream for loading the image data. This will return
   * without blocking on I/O.
   *
   * @param size the square dimensions to output the image at (unused), or -1
   * @param type return location for the content type of the image, or `null`
   * @param cancellable optional {@link GLib.Cancellable}, or `null`
   * @return an input stream providing access to the image data
   * @since UNRELEASED
   */
  public InputStream load (int size, out string? type,
      Cancellable? cancellable = null)
    {
      type = this._image_type;
      return new MemoryInputStream.from_data (this._image_data, free);
    }

  /**
   * Asynchronously build an input stream for loading the image data. This
   * will complete without blocking on I/O.
   *
   * @param size the square dimensions to output the image at (unused), or -1
   * @param cancellable optional {@link GLib.Cancellable}, or `null`
   * @param type return location for the content type of the image, or `null`
   * @return an input stream providing access to the image data
   * @since UNRELEASED
   */
  public async InputStream load_async (int size,
      GLib.Cancellable? cancellable, out string? type)
    {
      type = this._image_type;
      return new MemoryInputStream.from_data (this._image_data, free);
    }
}

/* vim: filetype=vala textwidth=80 tabstop=2 expandtab: */