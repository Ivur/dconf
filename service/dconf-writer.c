/*
 * Copyright © 2010 Codethink Limited
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the licence, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Author: Ryan Lortie <desrt@desrt.ca>
 */

#include "dconf-writer.h"

#include "dconf-shmdir.h"
#include "dconf-rebuilder.h"

#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>

static const gchar *dconf_writer_shm_dir;
static const gchar *dconf_writer_db_dir;

struct OPAQUE_TYPE__DConfWriter
{
  gchar *path;
  gchar *shm;
};

const gchar *
dconf_writer_get_shm_dir (void)
{
  return dconf_writer_shm_dir;
}

/* Each element must only contain the ASCII characters "[A-Z][a-z][0-9]_"
 */
static gboolean
is_valid_dbus_path_element (const gchar *string)
{
  gint i;

  for (i = 0; string[i]; i++)
    if (!g_ascii_isalnum (string[i]) && string[i] != '_')
      return FALSE;

  return TRUE;
}

gchar **
dconf_writer_list_existing (void)
{
  GPtrArray *array;
  GDir *dir;

  array = g_ptr_array_new ();

  if ((dir = g_dir_open ("/home/desrt/.config/dconf", 0, NULL)))
    {
      const gchar *name;

      while ((name = g_dir_read_name (dir)))
        if (is_valid_dbus_path_element (name))
          g_ptr_array_add (array, g_strdup (name));
    }

  g_ptr_array_add (array, NULL);

  return (gchar **) g_ptr_array_free (array, FALSE);
}

static void
dconf_writer_touch_shm (DConfWriter *writer)
{
  gchar one = 1;
  gint fd;

  fd = open (writer->shm, O_WRONLY);
  write (fd, &one, sizeof one);
  close (fd);

  unlink (writer->shm);
}

gboolean
dconf_writer_write (DConfWriter  *writer,
                    const gchar  *name,
                    GVariant     *value,
                    GError      **error)
{
  if (!dconf_rebuilder_rebuild (writer->path, "", &name, &value, 1, error))
    return FALSE;

  dconf_writer_touch_shm (writer);

  return TRUE;
}

gboolean
dconf_writer_write_many (DConfWriter          *writer,
                         const gchar          *prefix,
                         const gchar * const  *keys,
                         GVariant * const     *values,
                         gsize                 n_items,
                         GError              **error)
{
  if (!dconf_rebuilder_rebuild (writer->path, prefix, keys,
                                values, n_items, error))
    return FALSE;

  dconf_writer_touch_shm (writer);

  return TRUE;
}

gboolean
dconf_writer_set_lock (DConfWriter  *writer,
                       const gchar  *name,
                       gboolean      locked,
                       GError      **error)
{
  return TRUE;
}

DConfWriter *
dconf_writer_new (const gchar *name)
{
  DConfWriter *writer;

  writer = g_slice_new (DConfWriter);
  writer->path = g_build_filename (dconf_writer_db_dir, name, NULL);
  writer->shm = g_build_filename (dconf_writer_shm_dir, name, NULL);

  return writer;
}

void
dconf_writer_init (void)
{
  const gchar *config_dir = g_get_user_config_dir ();

  dconf_writer_db_dir = g_build_filename (config_dir, "dconf", NULL);

  if (g_mkdir_with_parents (dconf_writer_db_dir, 0700))
    {
      /* XXX remove this after a while... */
      if (errno == ENOTDIR)
        {
          gchar *tmp, *final;

          g_message ("Attempting to migrate ~/.config/dconf "
                     "to ~/.config/dconf/user");

          tmp = g_build_filename (config_dir, "dconf-user.db", NULL);

          if (rename (dconf_writer_db_dir, tmp))
            g_error ("Can not rename '%s' to '%s': %s",
                     dconf_writer_db_dir, tmp, g_strerror (errno));

          if (g_mkdir_with_parents (dconf_writer_db_dir, 0700))
            g_error ("Can not create directory '%s': %s",
                     dconf_writer_db_dir, g_strerror (errno));

          final = g_build_filename (dconf_writer_db_dir, "user", NULL);

          if (rename (tmp, final))
            g_error ("Can not rename '%s' to '%s': %s",
                     tmp, final, g_strerror (errno));

          g_message ("Successful.");

          g_free (final);
          g_free (tmp);
        }
      else
        g_error ("Can not create directory '%s': %s",
                 dconf_writer_db_dir, g_strerror (errno));
    }

  dconf_writer_shm_dir = dconf_shmdir_from_environment ();

  if (dconf_writer_shm_dir == NULL)
    {
      const gchar *tmpdir = g_get_tmp_dir ();
      gchar *shmdir;

      shmdir = g_build_filename (tmpdir, "dconf.XXXXXX", NULL);

      if ((dconf_writer_shm_dir = mkdtemp (shmdir)) == NULL)
        g_error ("Can not create reasonable shm directory");
    }
}
