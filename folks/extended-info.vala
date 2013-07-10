/*
 * Copyright (C) 2013 Collabora Ltd.
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
 *       Rodrigo Moya <rodrigo@gnome.org>
 */

using GLib;
using Gee;

/**
 * Object representing an arbitrary field that can have some parameters
 * associated with it.
 *
 * See {@link Folks.AbstractFieldDetails} for details on common parameter names
 * and values.
 *
 * @since UNRELEASED 
 */
public class Folks.ExtendedFieldDetails : AbstractFieldDetails<string>
{
  /**
   * Create a new ExtendedFieldDetails.
   *
   * @param value the value of the field
   * @param parameters initial parameters. See
   * {@link AbstractFieldDetails.parameters}. A ``null`` value is equivalent to
   * an empty map of parameters.
   *
   * @return a new ExtendedFieldDetails
   *
   * @since UNRELEASED
   */
  public ExtendedFieldDetails (string value,
                               MultiMap<string, string>? parameters = null)
    {
      if (value == "")
        {
          warning ("Empty value passed to ExtendedFieldDetails.");
        }

      this.value = value;
      if (parameters != null)
        this.parameters = (!) parameters;
	}

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override bool equal (AbstractFieldDetails<string> that)
    {
      return base.equal (that);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override uint hash ()
    {
      return base.hash ();
    }
}

/**
 * Arbitrary field interface.
 *
 * This interface allows clients to store arbitrary fields for contacts in backends
 * that support it.
 *
 * @since UNRELEASED
 */
public interface Folks.ExtendedInfo : Object
{
  /**
   * Retrieve the value for an arbitrary field.
   *
   * @since UNRELEASED
   */
  public abstract ExtendedFieldDetails? get_extended_field (string name);

  /**
   * Change the value of an arbitrary field.
   *
   * @param name name of the arbitrary field to change value
   * @param value new value for the arbitrary field
   * @throws PropertyError if setting the value failed
   *
   * @since UNRELEASED
   */
  public virtual async void change_extended_field (
      string name, ExtendedFieldDetails value) throws PropertyError
    {
      /* Default implementation */
      throw new PropertyError.NOT_WRITEABLE (
          _("Extended fields are not writeable on this contact."));
	}
}
