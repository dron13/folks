/*
 * Copyright (C) 2011 Collabora Ltd.
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
 *         Travis Reitter <travis.reitter@collabora.co.uk>
 *         Marco Barisione <marco.barisione@collabora.co.uk>
 *         Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using Gee;
using GLib;
using Folks;
using Tracker;
using Tracker.Sparql;

/**
 * A persona subclass which represents a single nco:Contact.
 */
public class Trf.Persona : Folks.Persona,
    AvatarDetails,
    BirthdayDetails,
    EmailDetails,
    FavouriteDetails,
    GenderDetails,
    ImDetails,
    NameDetails,
    NoteDetails,
    PhoneDetails,
    PostalAddressDetails,
    RoleDetails,
    UrlDetails
{
  private const string[] _linkable_properties =
      {"im-addresses", "email-addresses"};
  private GLib.List<FieldDetails> _phone_numbers;
  private GLib.List<FieldDetails> _email_addresses;
  private weak Sparql.Cursor _cursor;
  private string _tracker_id;

  /**
   * {@inheritDoc}
   */
  public GLib.List<FieldDetails> phone_numbers
    {
      get { return this._phone_numbers; }
      private set
        {
          this._phone_numbers = new GLib.List<FieldDetails> ();
          foreach (unowned FieldDetails ps in value)
            {
              this._phone_numbers.prepend (ps);
            }
          this._phone_numbers.reverse ();
        }
    }

  /**
   * {@inheritDoc}
   */
  public GLib.List<FieldDetails> email_addresses
    {
      get { return this._email_addresses; }
      private set
        {
          this._email_addresses = new GLib.List<FieldDetails> ();
          foreach (unowned FieldDetails e in value)
            {
              this._email_addresses.prepend (e);
            }
          this._email_addresses.reverse ();
        }
    }

  /**
   * {@inheritDoc}
   */
  public override string[] linkable_properties
    {
      get { return this._linkable_properties; }
    }

  /**
   * An avatar for the Persona.
   *
   * See {@link Folks.Avatar.avatar}.
   */
  public File avatar { get; set; }

  /**
   * {@inheritDoc}
   */
  public StructuredName structured_name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public string full_name { get; private set; }

  private string _nickname;
  /**
   * {@inheritDoc}
   */
  public string nickname { get { return this._nickname; } }

  /**
   * {@inheritDoc}
   */
  public Gender gender { get; private set; }

  private HashSet<Role> _roles =
      new HashSet<Role> ((GLib.HashFunc) Role.hash,
      (GLib.EqualFunc) Role.equal);

  public DateTime birthday { get; set; }

  public string calendar_event_id { get; set; }

  /**
   * {@inheritDoc}
   */
  public HashSet<Role> roles
    {
      get { return this._roles; }
      private set
        {
          this._roles = value;
          this.notify_property ("roles");
        }
    }

  private HashSet<Note> _notes =
      new HashSet<Note> ((GLib.HashFunc) Note.hash,
      (GLib.EqualFunc) Note.equal);

  /**
   * {@inheritDoc}
   */
  public HashSet<Note> notes
    {
      get { return this._notes; }
      private set
        {
          this._notes = notes;
          this.notify_property ("notes");
        }
    }

  private GLib.List<FieldDetails> _urls;
  /**
   * {@inheritDoc}
   */
  public GLib.List<FieldDetails> urls
    {
      get { return this._urls; }
      private set
        {
          this._urls = new GLib.List<FieldDetails> ();
          foreach (unowned FieldDetails ps in value)
            this._urls.prepend (ps);
          this._urls.reverse ();
        }
    }

  private GLib.List<PostalAddress> _postal_addresses =
      new GLib.List<PostalAddress> ();
  /**
   * {@inheritDoc}
   */
  public GLib.List<PostalAddress> postal_addresses
    {
      get { return this._postal_addresses; }
      private set
        {
          this._postal_addresses = new GLib.List<PostalAddress> ();
          foreach (PostalAddress pa in value)
            this._postal_addresses.prepend (pa);
          this._postal_addresses.reverse ();
          this.notify_property ("postal-addresses");
        }
    }

  private HashTable<string, HashTable<string, string>> _tracker_ids_ims =
  new HashTable<string, HashTable<string, string>> (str_hash, str_equal);

  private HashTable<string, LinkedHashSet<string>> _im_addresses =
      new HashTable<string, LinkedHashSet<string>> (str_hash, str_equal);
  /**
   * {@inheritDoc}
   */
  public HashTable<string, LinkedHashSet<string>> im_addresses
    {
      get { return this._im_addresses; }
      private set {}
    }

  /**
   * Whether this contact is a user-defined favourite.
   */
  public bool is_favourite { get; set; }

  /**
   * Build a IID.
   *
   * @param store_id the {@link PersonaStore.id}
   * @param tracker_id the tracker id belonging to nco:PersonContact
   * @return a valid IID
   *
   * @since UNRELEASED
   */
  internal static string build_iid (string store_id, string tracker_id)
    {
      return "%s:%s".printf (store_id, tracker_id);
    }

  /**
   * Create a new persona.
   *
   * Create a new persona for the {@link PersonaStore} `store`, representing
   * the nco:Contact whose details are stored in the cursor.
   */
  public Persona (PersonaStore store, string tracker_id,
                  Sparql.Cursor? cursor = null)
    {
      string uid = this.build_uid (BACKEND_NAME, store.id, tracker_id);
      string iid = this.build_iid (store.id, tracker_id);
      bool is_user = false;
      string fullname = "";

      if (cursor != null)
        {
          fullname = cursor.get_string (Trf.Fields.FULL_NAME).dup ();
          var contact_urn = cursor.get_string (Trf.Fields.CONTACT_URN);
          if (contact_urn == Trf.OntologyDefs.DEFAULT_CONTACT_URN)
            {
              is_user = true;
            }
        }

      debug ("Creating new Trf.Persona with id '%s'", fullname);

      Object (display_id: fullname,
              uid: uid,
              iid: iid,
              store: store,
              gender: Gender.UNSPECIFIED,
              is_user: is_user);

      this.full_name = fullname;
      this._tracker_id = tracker_id;
      this.structured_name = new StructuredName (null, null, null, null, null);

      if (cursor != null)
        {
          this._cursor = cursor;
          this._update ();
        }
    }

  ~Persona ()
    {
      debug ("Destroying Trf.Persona '%s': %p", this.uid, this);
    }

  internal void _update_full_name (string? fn)
    {
      if (fn != null && this.full_name != fn)
        {
          this.full_name = fn;
        }
    }

  internal void _update_nickname (string? nickname)
    {
      if (nickname != null && this._nickname != nickname)
        {
          this._nickname = nickname;
          this.notify_property ("nickname");
        }
    }

  internal void _update_family_name (string? family_name)
    {
      if (family_name != null)
        {
          this.structured_name.family_name = family_name;
        }
    }

  internal void _update_given_name (string? given_name)
    {
      if (given_name != null)
        {
          this.structured_name.given_name = given_name;
        }
    }

  internal void _update_additional_names (string? additional_names)
    {
      if (additional_names != null)
        {
          this.structured_name.additional_names = additional_names;
        }
    }

  internal void _update_prefixes (string? prefixes)
    {
      if (prefixes != null)
        {
          this.structured_name.prefixes = prefixes;
        }
    }

  internal void _update_suffixes (string? suffixes)
    {
      if (suffixes != null)
        {
          this.structured_name.suffixes = suffixes;
        }
    }

  internal void _update ()
    {
      this._update_names ();
      this._update_avatar ();
      this._update_im_addresses ();
      this._update_phones ();
      this._update_email_addresses ();
      this._update_urls ();
      this._update_favourite ();
      this._update_roles ();
      this._update_bday ();
      this._update_note ();
      this._update_gender ();
      this._update_postal_addresses ();
    }

  private void _update_postal_addresses ()
    {
      string postal_field = this._cursor.get_string
          (Trf.Fields.POSTAL_ADDRESS).dup ();

      if (postal_field == null)
        {
          return;
        }

      GLib.List<PostalAddress> postal_addresses =
          new GLib.List<PostalAddress> ();

      string[] addresses_a = postal_field.split ("\n");

      foreach (var a in addresses_a)
        {
          bool address_empty = true;
          string[] a_info = a.split ("\t");
          for (int i = 0; i < a_info.length; i++)
            {
              if (a_info[i] != null && a_info[i] != "")
                {
                  address_empty = false;
                  break;
                }
            }

          if (address_empty)
            continue;

          GLib.List<string> types = new GLib.List<string> ();

          var pa = new PostalAddress (a_info[Trf.PostalAddressFields.POBOX],
              a_info[Trf.PostalAddressFields.EXTENDED_ADDRESS],
              a_info[Trf.PostalAddressFields.STREET_ADDRESS],
              a_info[Trf.PostalAddressFields.LOCALITY],
              a_info[Trf.PostalAddressFields.REGION],
              a_info[Trf.PostalAddressFields.POSTALCODE],
              a_info[Trf.PostalAddressFields.COUNTRY],
              null, (owned) types,
              a_info[Trf.PostalAddressFields.TRACKER_ID]);

          postal_addresses.prepend ((owned) pa);
        }

      postal_addresses.reverse ();
      this.postal_addresses = (owned) postal_addresses;
    }

  internal bool _add_postal_address (PostalAddress postal_address)
    {
      foreach (unowned PostalAddress pa in this._postal_addresses)
        {
          if (postal_address.equal (pa))
            {
              return false;
            }
        }

      this._postal_addresses.append (postal_address);
      this.notify_property ("postal-addresses");
      return true;
    }

  internal bool _remove_postal_address (string tracker_id)
    {
      foreach (unowned PostalAddress pa in this._postal_addresses)
        {
          if (pa.uid == tracker_id)
            {
              this._postal_addresses.remove (pa);
              this.notify_property ("postal-addresses");
              return true;
            }
        }
      return false;
    }

  private void _update_gender ()
    {
      string gender = this._cursor.get_string (Trf.Fields.GENDER).dup ();
      int gender_id = 0;

      if (gender != null)
        {
          gender_id = int.parse (gender);
        }

      this._set_gender (gender_id);
    }

  internal void _set_gender (int gender_id)
    {
      if (gender_id == 0)
        {
          this.gender = Gender.UNSPECIFIED;
        }
      else
        {
          var trf_store = (Trf.PersonaStore) this.store;

          if (gender_id == trf_store.get_gender_male_id ())
            {
              this.gender = Gender.MALE;
            }
          else if (gender_id == trf_store.get_gender_female_id ())
            {
              this.gender = Gender.FEMALE;
            }
        }
    }

  private void _update_note ()
    {
      string note = this._cursor.get_string (Trf.Fields.NOTE).dup ();
      this._set_note (note);
    }

  internal void _set_note (string? note_content)
    {
      if (note_content != null)
        {
          var note = new Note (note_content);
          this._notes.add ((owned) note);
        }
      else
        {
          this._notes.clear ();
        }
      this.notify_property ("notes");
    }

  private void _update_bday ()
    {
      string bday = this._cursor.get_string (Trf.Fields.BIRTHDAY).dup ();
      this._set_birthday (bday);
    }

  internal void _set_birthday (string? birthday)
    {
      if (birthday != null && birthday != "")
        {
          TimeVal t = TimeVal ();
          t.from_iso8601 (birthday);
          this.birthday = new DateTime.from_timeval_utc (t);
        }
      else
        {
          if (this.birthday != null)
            {
              this.birthday = null;
            }
        }
    }

  private void _update_roles ()
    {
      string roles_field = this._cursor.get_string (
          Trf.Fields.ROLES).dup ();

      if (roles_field == null)
        {
          return;
        }

      HashSet<Role> roles = new HashSet<Role> (
          (GLib.HashFunc) Role.hash,
          (GLib.EqualFunc) Role.equal);

      string[] roles_a = roles_field.split ("\n");

      foreach (var r in roles_a)
        {
          string[] r_info = r.split ("\t");
          var tracker_id = r_info[Trf.RoleFields.TRACKER_ID];
          var title = r_info[Trf.RoleFields.ROLE];
          var organisation = r_info[Trf.RoleFields.DEPARTMENT];

          var role = new Role (title, organisation, tracker_id);
          roles.add (role);
        }

      this._roles = roles;
    }

  internal bool _add_role (string tracker_id, string? title, string? org)
    {
      var role = new Role (title, org, tracker_id);
      if (this._roles.add (role))
        {
          this.notify_property ("roles");
          return true;
        }
      return false;
    }

  internal bool _remove_role (string tracker_id)
    {
      foreach (var r in this._roles)
        {
          if (r.uid == tracker_id)
            {
              this._roles.remove (r);
              this.notify_property ("roles");
              return true;
            }
        }

      return false;
    }

  private void _update_names ()
    {
      string fullname = this._cursor.get_string (Trf.Fields.FULL_NAME).dup ();
      this._update_full_name (fullname);

      string nickname = this._cursor.get_string (Trf.Fields.NICKNAME).dup ();
      this._update_nickname (nickname);

      string family_name = this._cursor.get_string (
          Trf.Fields.FAMILY_NAME).dup ();
      this._update_family_name (family_name);

      string given_name  = this._cursor.get_string (
          Trf.Fields.GIVEN_NAME).dup ();
      this._update_given_name (given_name);

      string additional_names = this._cursor.get_string (
          Trf.Fields.ADDITIONAL_NAMES).dup ();
      this._update_additional_names (additional_names);

      string prefixes = this._cursor.get_string (Trf.Fields.PREFIXES).dup ();
      this._update_prefixes (prefixes);

      string suffixes = this._cursor.get_string (Trf.Fields.SUFFIXES).dup ();
      this._update_suffixes (suffixes);
    }

  private void _update_avatar ()
    {
      string avatar_url = this._cursor.get_string (
          Trf.Fields.AVATAR_URL).dup ();
      this._set_avatar (avatar_url);
    }

  internal bool _set_avatar (string? avatar_url)
    {
      File _avatar = null;
      if (avatar_url != null && avatar_url != "")
        {
          _avatar = File.new_for_uri (avatar_url);
        }
      this.avatar = _avatar;
      return true;
    }

  private void _update_im_addresses ()
    {
      string addresses = this._cursor.get_string (
          Trf.Fields.IM_ADDRESSES).dup ();

      if (addresses == null)
        {
          return;
        }

      this._im_addresses.remove_all ();

      string[] addresses_a = addresses.split ("\n");

      foreach (var addr in addresses_a)
        {
          string[] addr_info = addr.split ("\t");
          var tracker_id = addr_info[Trf.IMFields.TRACKER_ID];
          var proto = addr_info[Trf.IMFields.PROTO];
          var account_id = addr_info[Trf.IMFields.ID];

          this._add_im_address (tracker_id, proto, account_id, false);
        }

      this.notify_property ("im-addresses");
    }

  internal bool _add_im_address (string tracker_id, string im_proto,
      string account_id, bool notify = true)
    {
      LinkedHashSet<string> im_address_array;

      try
        {
          var account_id_copy = account_id.dup ();
          var normalised_addr = (owned) normalise_im_address
              ((owned) account_id_copy, im_proto);

          im_address_array = this._im_addresses.lookup (im_proto);
          if (im_address_array == null)
            {
              im_address_array = new LinkedHashSet<string> ();
              im_address_array.add ((owned) normalised_addr);
              var proto_copy = im_proto.dup ();
              this._im_addresses.insert ((owned) proto_copy,
                  (owned) im_address_array);
            }
          else
            {
              im_address_array.add (normalised_addr);
            }

          var im_proto_hash = new HashTable<string, string> (str_hash,
              str_equal);
          var proto_copy_2 = im_proto.dup ();
          var account_id_copy_2 = account_id.dup ();
          im_proto_hash.insert ((owned) proto_copy_2,
              (owned) account_id_copy_2);
          var tracker_id_copy = tracker_id.dup ();
          this._tracker_ids_ims.insert ((owned) tracker_id_copy,
                  (owned) im_proto_hash);

          if (notify)
            {
              this.notify_property ("im-addresses");
            }
        }
      catch (Folks.ImDetailsError e)
        {
          GLib.warning (
              "Problem when trying to normalise address: %s\n",
              e.message);
        }

      return true;
    }

  internal bool _remove_im_address (string tracker_id, bool notify = true)
    {
      var proto_im = this._tracker_ids_ims.lookup (tracker_id);

      if (proto_im == null)
        return false;

      var proto = proto_im.get_keys ().nth_data (0);
      var im_addr = proto_im.lookup (proto);

      var im_list = this._im_addresses.lookup (proto);
      if (im_list != null)
        {
          foreach (var addr_iter in im_list)
            {
              if (addr_iter == im_addr)
                {
                  im_list.remove (im_addr);
                  this._tracker_ids_ims.remove (tracker_id);
                  if (notify)
                    {
                      this.notify_property ("im-addresses");
                    }
                  return true;
                }
            }
        }

      return false;
    }

  private void _update_phones ()
    {
      string phones_field = this._cursor.get_string (Trf.Fields.PHONES).dup ();

      if (phones_field == null)
        {
          return;
        }

      var phones = new GLib.List<FieldDetails> ();
      string[] phones_a = phones_field.split ("\n");

      foreach (var p in phones_a)
        {
          if (p != null && p != "")
            {
              string[] p_info = p.split ("\t");
              var fd = new FieldDetails (p_info[Trf.PhoneFields.PHONE]);
              fd.set_parameter ("tracker_id",
                  p_info[Trf.PhoneFields.TRACKER_ID]);
              phones.prepend ((owned) fd);
            }
        }

      phones.reverse ();
      this.phone_numbers = phones;
    }

  internal bool _add_phone (string phone, string tracker_id)
    {
      bool found = false;

      foreach (var p in this._phone_numbers)
        {
          var current_tracker_id =
              p.get_parameter_values ("tracker_id").nth_data (0);
          if (tracker_id == current_tracker_id)
            {
              found = true;
              break;
            }
        }

      if (!found)
        {
          var fd = new FieldDetails (phone);
          fd.set_parameter ("tracker_id", tracker_id);
          this._phone_numbers.prepend ((owned) fd);
          this.notify_property ("phone-numbers");
        }

      return !found;
    }

  internal bool _remove_phone (string tracker_id)
    {
      bool found = false;

      foreach (var p in this._phone_numbers)
        {
          var current_tracker_id = p.get_parameter_values
              ("tracker_id").nth_data(0);
          if (tracker_id == current_tracker_id)
            {
              this._phone_numbers.remove (p);
              found = true;
              break;
            }
        }

      if (found)
       {
         this.notify_property ("phone-numbers");
       }

      return found;
    }

  internal bool _add_email (string addr, string tracker_id)
    {
      bool found = false;

      foreach (var e in this._email_addresses)
        {
          var current_tracker_id =
              e.get_parameter_values ("tracker_id").nth_data (0);
          if (tracker_id == current_tracker_id)
            {
              found = true;
              break;
            }
        }

      if (!found)
        {
          var fd = new FieldDetails (addr);
          fd.set_parameter ("tracker_id", tracker_id);
          this._email_addresses.prepend ((owned) fd);
          this.notify_property ("email-addresses");
        }

      return !found;
    }

  internal bool _remove_email (string tracker_id)
    {
      bool found = false;

      foreach (var e in this._email_addresses)
        {
          var current_tracker_id =
              e.get_parameter_values ("tracker_id").nth_data(0);
          if (tracker_id == current_tracker_id)
            {
              this._email_addresses.remove (e);
              found = true;
              break;
            }
        }

      if (found)
       {
         this.notify_property ("email-addresses");
       }

      return found;
    }

  private void _update_email_addresses ()
    {
      string emails_field = this._cursor.get_string (Trf.Fields.EMAILS).dup ();

      if (emails_field == null)
        {
          return;
        }

      var email_addresses = new GLib.List<FieldDetails> ();
      string[] emails_a = emails_field.split (",");

      foreach (var e in emails_a)
        {
          if (e != null && e != "")
            {
              string[] id_addr = e.split ("\t");
              var fd = new FieldDetails (id_addr[Trf.EmailFields.EMAIL]);
              fd.set_parameter ("tracker_id",
                  id_addr[Trf.EmailFields.TRACKER_ID]);
              email_addresses.prepend ((owned) fd);
            }
        }

      email_addresses.reverse ();
      this.email_addresses = email_addresses;
    }

  private void _update_urls ()
    {
      var urls = new GLib.List<FieldDetails> ();
      var _urls_field = this._cursor.get_string (Trf.Fields.URLS).dup ();

      if (_urls_field == null)
        return;

      string[] urls_table = _urls_field.split ("\n");

      foreach (var row in urls_table)
        {
          string[] u = row.split ("\t");
          var tracker_id = u[Trf.UrlsFields.TRACKER_ID];

          for (int i=1; i< u.length; i++)
            {
              if (u[i] == null || u[i] == "")
                continue;

              string type = "";
              switch (i)
                {
                  case Trf.UrlsFields.BLOG:
                    type = "blog";
                    break;
                  case Trf.UrlsFields.WEBSITE:
                    type = "website";
                    break;
                  case Trf.UrlsFields.URL:
                    type = "url";
                    break;
                }

              var fd = new FieldDetails (u[i]);
              fd.set_parameter ("tracker_id", tracker_id);
              fd.set_parameter ("type", type);
              urls.prepend ((owned) fd);
            }
        }

      urls.reverse ();
      this.urls = urls;
    }

  internal bool _add_url (string url, string tracker_id, string type = "")
    {
      bool found = false;

      foreach (var p in this._urls)
        {
          var t_id = p.get_parameter_values ("tracker_id").nth_data (0);
          if (tracker_id == t_id)
            {
              found = true;
              break;
            }
        }

      if (!found)
        {
          var fd = new FieldDetails (url);
          fd.set_parameter ("tracker_id", tracker_id);
          fd.set_parameter ("type", type);
          this._urls.prepend ((owned) fd);
          this.notify_property ("urls");
        }

      return !found;
    }

  internal bool _remove_url (string tracker_id)
    {
      bool found = false;

      foreach (var u in this._urls)
        {
          var current_tracker_id = u.get_parameter_values
              ("tracker_id").nth_data(0);
          if (tracker_id == current_tracker_id)
            {
              this._urls.remove (u);
              found = true;
            }
        }

      if (found)
        this.notify_property ("urls");

      return found;
    }

  private void _update_favourite ()
    {
      var favourite = this._cursor.get_string (Trf.Fields.FAVOURITE).dup ();

      this.is_favourite = false;

      if (favourite != null)
        {
          var trf_store = (Trf.PersonaStore) this.store;
          int favorite_tracker_id = trf_store.get_favorite_id ();
          foreach (var tag in favourite.split (","))
            {
              if (int.parse (tag) == favorite_tracker_id)
                {
                  this.is_favourite = true;
                }
            }
        }
    }
}
