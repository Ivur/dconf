public class SchemaKey
{
    public Schema schema;
    public string name;
    public string type;
    public Variant default_value;
    public SchemaValueRange? range;
    public SchemaValueRange type_range;
    public List<SchemaChoice> choices;
    public string? enum_name;
    public string? summary;
    public string? description;
    public string? gettext_domain;

    public SchemaKey.from_xml(Xml.Node* node, Schema schema, string? gettext_domain)
    {
        this.schema = schema;
        this.gettext_domain = gettext_domain;

        for (var prop = node->properties; prop != null; prop = prop->next)
        {
            if (prop->name == "name")
                name = prop->children->content;
            else if (prop->name == "type")
                type = prop->children->content;
            else if (prop->name == "enum")
            {
                type = "s";
                enum_name = prop->children->content;
            }
			else if (prop->name == "flags")
				/* TODO: support this properly */
				type = "as";
            else
                warning ("Unknown property on <key>, %s", prop->name);
        }

        //if (name == null || type == null)
        //    ?

        for (var child = node->children; child != null; child = child->next)
        {
            if (child->name == "default")
            {
                try
                {
                    default_value = Variant.parse(new VariantType(type), child->children->content);
                }
                catch (VariantParseError e)
                {
                    // ...
                }
            }
            else if (child->name == "summary")
                summary = child->children->content;
            else if (child->name == "description")
                description = child->children->content;
            else if (child->name == "range")
                range = new SchemaValueRange.from_xml(type, child);
            else if (child->name == "choices")
            {
                for (var n = child->children; n != null; n = n->next)
                {
                    if (n->type != Xml.ElementType.ELEMENT_NODE)
                        continue;
                    if (n->name != "choice")
                    {
                        warning ("Unknown child tag in <choices>, <%s>", n->name);
                        continue;
                    }

                    string? value = null;
                    for (var prop = n->properties; prop != null; prop = prop->next)
                    {
                        if (prop->name == "value")
                            value = prop->children->content;
                        else
                            warning ("Unknown property on <choice>, %s", prop->name);
                    }

                    if (value == null)
                    {
                        warning ("Ignoring <choice> with no value");
                        continue;
                    }

                    Variant v;
                    try
                    {
                        v = new Variant.string (value);
                        choices.append (new SchemaChoice(value, v));
                    }
                    catch (VariantParseError e)
                    {
                        warning ("Invalid choice value '%s'", value);
                    }
                }
            }
            else if (child->name == "aliases")
            {
                for (var n = child->children; n != null; n = n->next)
                {
                    if (n->type != Xml.ElementType.ELEMENT_NODE)
                        continue;
                    if (n->name != "alias")
                    {
                        warning ("Unknown child tag in <aliases>, <%s>", n->name);
                        continue;
                    }

                    string? value = null, target = null;
                    for (var prop = n->properties; prop != null; prop = prop->next)
                    {
                        if (prop->name == "value")
                            value = prop->children->content;
                        else if (prop->name == "target")
                            target = prop->children->content;
                        else
                            warning ("Unknown property on <alias>, %s", prop->name);
                    }

                    if (value == null)
                    {
                        warning ("Ignoring <alias> with no value");
                        continue;
                    }
                    if (target == null)
                    {
                        warning ("Ignoring <alias> with no target");
                        continue;
                    }

                    Variant v;
                    try
                    {
                        v = new Variant.string (target);
                        choices.append (new SchemaChoice(value, v));
                    }
                    catch (VariantParseError e)
                    {
                        warning ("Invalid alias value '%s'", target);
                    }
                }
            }
            else if (child->type != Xml.ElementType.TEXT_NODE && child->type != Xml.ElementType.COMMENT_NODE)
                warning ("Unknown child tag in <key>, <%s>", child->name);
        }

        //if (default_value == null)
        //    ?
    }
}

public class SchemaEnumValue : GLib.Object
{
    public SchemaEnum schema_enum;
    public uint index;
    public string nick;
    public int value;

    public SchemaEnumValue(SchemaEnum schema_enum, uint index, string nick, int value)
    {
        this.schema_enum = schema_enum;
        this.index = index;
        this.nick = nick;
        this.value = value;
    }
}

public class SchemaChoice
{
    public string name;
    public Variant value;

    public SchemaChoice(string name, Variant value)
    {
        this.name = name;
        this.value = value;
    }
}

public class SchemaValueRange
{
    public Variant min;
    public Variant max;
   
    public SchemaValueRange.from_xml(string type, Xml.Node* node)
    {
        for (var prop = node->properties; prop != null; prop = prop->next)
        {
            if (prop->name == "min")
            {
                try
                {
                    min = Variant.parse(new VariantType(type), prop->children->content);
                }
                catch (VariantParseError e)
                {
                    // ...
                }
            }
            else if (prop->name == "max")
            {
                try
                {
                    max = Variant.parse(new VariantType(type), prop->children->content);
                }
                catch (VariantParseError e)
                {
                    // ...
                }
            }
            else
                warning ("Unknown property in <range>, %s", prop->name);
        }
        
        //if (min == null || max == null)
        //    ?
    }
}

public class SchemaEnum
{
    public SchemaList list;
    public string id;
    public GLib.List<SchemaEnumValue> values = new GLib.List<SchemaEnumValue>();

    public SchemaEnum.from_xml(SchemaList list, Xml.Node* node)
    {
        this.list = list;

        for (var prop = node->properties; prop != null; prop = prop->next)
        {
            if (prop->name == "id")
                id = prop->children->content;
            else
                warning ("Unknown property in <enum>, %s", prop->name);
        }

        //if (id = null)
        //    ?

        for (var child = node->children; child != null; child = child->next)
        {
            if (child->name == "value")
            {
                string? nick = null;
                int value = -1;

                for (var prop = child->properties; prop != null; prop = prop->next)
                {
                    if (prop->name == "value")
                        value = int.parse(prop->children->content);
                    else if (prop->name == "nick")
                        nick = prop->children->content;
                    else
                        warning ("Unknown property in enum <value>, %s", prop->name);
                }

                //if (value < 0 || nick == null)
                //    ?

                SchemaEnumValue schema_value = new SchemaEnumValue(this, values.length(), nick, value);
                values.append(schema_value);
            }
            else if (child->type != Xml.ElementType.TEXT_NODE && child->type != Xml.ElementType.COMMENT_NODE)
                warning ("Unknown tag in <enum>, <%s>", child->name);
        }
        
        //if (default_value == null)
        //    ?
    }
}

public class Schema
{
    public SchemaList list;
    public string id;
    public string? path;
    public GLib.HashTable<string, SchemaKey> keys = new GLib.HashTable<string, SchemaKey>(str_hash, str_equal);

    public Schema.from_xml(SchemaList list, Xml.Node* node, string? gettext_domain)
    {
        this.list = list;

        for (var prop = node->properties; prop != null; prop = prop->next)
        {
            if (prop->name == "id")
                id = prop->children->content;
            else if (prop->name == "path")
                path = prop->children->content; // FIXME: Does the path have to end with '/'?
            else if (prop->name == "gettext-domain")
                gettext_domain = prop->children->content;
            else
                warning ("Unknown property on <schema>, %s", prop->name);
        }

        //if (id == null)
            //?

        for (var child = node->children; child != null; child = child->next)
        {
            if (child->name != "key")
               continue;
            var key = new SchemaKey.from_xml(child, this, gettext_domain);
            keys.insert(key.name, key);
        }
    }
}

public class SchemaList
{
    public GLib.List<Schema> schemas = new GLib.List<Schema>();
    public GLib.HashTable<string, SchemaKey> keys = new GLib.HashTable<string, SchemaKey>(str_hash, str_equal);
    public GLib.HashTable<string, SchemaEnum> enums = new GLib.HashTable<string, SchemaEnum>(str_hash, str_equal);

    public void parse_file(string path)
    {
        var doc = Xml.Parser.parse_file(path);
        if (doc == null)
            return;

        var root = doc->get_root_element();
        if (root == null)
            return;
        if (root->name != "schemalist")
            return;

        string? gettext_domain = null;
        for (var prop = root->properties; prop != null; prop = prop->next)
        {
            if (prop->name == "gettext-domain")
                gettext_domain = prop->children->content;
        }

        for (var node = root->children; node != null; node = node->next)
        {
            if (node->name == "schema")
            {
                Schema schema = new Schema.from_xml(this, node, gettext_domain);
                if (schema.path == null)
                {
                    // FIXME: What to do here?
                    continue;
                }

                foreach (var key in schema.keys.get_values())
                {
                    string full_name = schema.path + key.name;
                    keys.insert(full_name, key);
                }
                schemas.append(schema);
            }
            else if (node->name == "enum")
            {
                SchemaEnum enum = new SchemaEnum.from_xml(this, node);
                enums.insert(enum.id, enum);
            }
            else if (node->type != Xml.ElementType.TEXT_NODE)
                warning ("Unknown tag <%s>", node->name);
        }

        delete doc;
    }

    public void load_directory(string dir) throws Error
    {
        File directory = File.new_for_path(dir);
        var i = directory.enumerate_children (FILE_ATTRIBUTE_STANDARD_NAME, 0, null);
        FileInfo info;
        while ((info = i.next_file (null)) != null) {
            string name = info.get_name();

            if (!name.has_suffix(".gschema.xml") && !name.has_suffix(".enums.xml"))
                continue;

            string path = Path.build_filename(dir, name, null);
            debug("Loading schema: %s", path);
            parse_file(path);
        }
    }
}
