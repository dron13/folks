/*
 * Copyright (C) 2010 Collabora Ltd.
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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using GLib;
using Gee;
using TelepathyGLib;
using Folks;

private struct AccountFavourites
{
  ObjectPath account_path;
  string[] ids;
}

[DBus (name = "org.freedesktop.Telepathy.Logger.DRAFT")]
private interface LoggerIface : Object
{
  public abstract async AccountFavourites[] get_favourite_contacts ()
      throws GLib.Error;
  public abstract async void add_favourite_contact (
      ObjectPath account_path, string id) throws GLib.Error;
  public abstract async void remove_favourite_contact (
      ObjectPath account_path, string id) throws GLib.Error;

  public abstract signal void favourite_contacts_changed (
      ObjectPath account_path, string[] added, string[] removed);
}

internal class Logger : GLib.Object
{
  private static LoggerIface _logger;
  private string _account_path;
  private uint _logger_watch_id;

  public signal void invalidated ();
  public signal void favourite_contacts_changed (string[] added,
      string[] removed);

  public Logger (string account_path)
    {
      this._account_path = account_path;
    }

  ~Logger ()
    {
      /* Can only be 0 if prepare() hasn't been called. */
      if (this._logger_watch_id > 0)
        {
          Bus.unwatch_name (this._logger_watch_id);
        }
    }

  public async bool prepare () throws GLib.Error
    {
      bool retval = false;

      if (this._logger == null)
        {
          /* Create a logger proxy for favourites support */
          var dbus_conn = yield Bus.get (BusType.SESSION);
          this._logger = yield dbus_conn.get_proxy<LoggerIface> (
              "org.freedesktop.Telepathy.Logger",
              "/org/freedesktop/Telepathy/Logger");

          /* Failure? */
          if (this._logger == null)
            {
              this.invalidated ();
              return retval;
            }

          this._logger_watch_id = Bus.watch_name_on_connection (dbus_conn,
              "org.freedesktop.Telepathy.Logger", BusNameWatcherFlags.NONE,
              null, this._logger_vanished);

          retval = true;
        }

      this._logger.favourite_contacts_changed.connect ((ap, a, r) =>
        {
          if (ap != this._account_path)
            return;

          this.favourite_contacts_changed (a, r);
        });

      return retval;
    }

  private void _logger_vanished (DBusConnection conn, string name)
    {
      /* The logger has vanished on the bus, so it and we are no longer valid */
      this._logger = null;
      this.invalidated ();
    }

  public async string[] get_favourite_contacts () throws GLib.Error
    {
      /* Invalidated */
      if (this._logger == null)
        return {};

      /* Use an intermediate, since this._logger could disappear before this
       * async function finishes */
      var logger = this._logger;
      AccountFavourites[] favs = yield logger.get_favourite_contacts ();

      foreach (AccountFavourites account in favs)
        {
          /* We only want the favourites from this account */
          if (account.account_path == this._account_path)
            return account.ids;
        }

      return {};
    }

  public async void add_favourite_contact (string id) throws GLib.Error
    {
      /* Invalidated */
      if (this._logger == null)
        return;

      /* Use an intermediate, since this._logger could disappear before this
       * async function finishes */
      var logger = this._logger;
      yield logger.add_favourite_contact (
          new ObjectPath (this._account_path), id);
    }

  public async void remove_favourite_contact (string id) throws GLib.Error
    {
      /* Invalidated */
      if (this._logger == null)
        return;

      /* Use an intermediate, since this._logger could disappear before this
       * async function finishes */
      var logger = this._logger;
      yield logger.remove_favourite_contact (
          new ObjectPath (this._account_path), id);
    }
}
