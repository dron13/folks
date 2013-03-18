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
 * Authors: Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *
 */

using Tracker.Sparql;
using TrackerTest;
using Folks;
using Gee;

public class NicknameUpdatesTests : TrackerTest.TestCase
{
  private IndividualAggregator _aggregator;
  private bool _updated_nickname_found;
  private string _updated_nickname;
  private string _individual_id;
  private GLib.MainLoop _main_loop;
  private string _initial_fullname;
  private string _contact_urn;

  public NicknameUpdatesTests ()
    {
      base ("NicknameUpdates");

      ((!) this.tracker_backend).debug = false;

      this.add_test ("nickname updates", this.test_nickname_updates);
    }

  public void test_nickname_updates ()
    {
      this._main_loop = new GLib.MainLoop (null, false);
      Gee.HashMap<string, string> c1 = new Gee.HashMap<string, string> ();
      this._initial_fullname = "persona #1";
      this._updated_nickname = "updated nickname #1";
      this._contact_urn = "<urn:contact001>";

      c1.set (TrackerTest.Backend.URN, this._contact_urn);
      c1.set (Trf.OntologyDefs.NCO_FULLNAME, this._initial_fullname);
      ((!) this.tracker_backend).add_contact (c1);

      ((!) this.tracker_backend).set_up ();

      this._updated_nickname_found = false;
      this._individual_id = "";

      this._test_nickname_updates_async.begin ();

      Timeout.add_seconds (5, () =>
        {
          this._main_loop.quit ();
          assert_not_reached ();
        });

      this._main_loop.run ();

      assert (this._updated_nickname_found == true);
    }

  private async void _test_nickname_updates_async ()
    {
      var store = BackendStore.dup ();
      yield store.prepare ();
      this._aggregator = new IndividualAggregator ();
      this._aggregator.individuals_changed_detailed.connect
          (this._individuals_changed_cb);
      try
        {
          yield this._aggregator.prepare ();
        }
      catch (GLib.Error e)
        {
          GLib.warning ("Error when calling prepare: %s\n", e.message);
        }
    }

  private void _individuals_changed_cb (
       MultiMap<Individual?, Individual?> changes)
    {
      var added = changes.get_values ();
      var removed = changes.get_keys ();

      foreach (var i in added)
        {
          assert (i != null);

          if (i.full_name == this._initial_fullname)
            {
              i.notify["nickname"].connect (this._notify_nickname_cb);
              this._individual_id = i.id;

              var im_addr = "<urn:im-address>";
              ((!) this.tracker_backend).insert_triplet (im_addr,
                  "a", Trf.OntologyDefs.NCO_IMADDRESS,
                  Trf.OntologyDefs.NCO_IM_NICKNAME, this._updated_nickname);

              var affl = "<urn:im-affl>";
              ((!) this.tracker_backend).insert_triplet (affl,
                  "a", Trf.OntologyDefs.NCO_AFFILIATION);

               ((!) this.tracker_backend).insert_triplet (affl,
                 Trf.OntologyDefs.NCO_HAS_IMADDRESS, im_addr);

              ((!) this.tracker_backend).insert_triplet (this._contact_urn,
                  Trf.OntologyDefs.NCO_HAS_AFFILIATION, affl);
            }
        }

      assert (removed.size == 1);

      foreach (var i in removed)
        {
          assert (i == null);
        }
    }

  private void _notify_nickname_cb (Object individual_obj, ParamSpec ps)
    {
      Folks.Individual i = (Folks.Individual) individual_obj;
      if (i.nickname == this._updated_nickname)
        {
          this._updated_nickname_found = true;
          this._main_loop.quit ();
        }
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  var tests = new NicknameUpdatesTests ();
  tests.register ();
  Test.run ();
  tests.final_tear_down ();

  return 0;
}
