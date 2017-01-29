using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Xml.Linq;
using JetBrains.Annotations;
using XyrusWorx.Collections;

namespace XyrusWorx.Management.IO
{
	[PublicAPI]
	public class XmlNode
	{
		private readonly Dictionary<StringKeySequence, List<XmlNode>> mChildren;
		private readonly Dictionary<StringKeySequence, List<string>> mValues;

		private readonly string mText;
		private readonly StringKey mNamespace;
		private static readonly XmlNode mEmpty;

		static XmlNode()
		{
			mEmpty = new XmlNode();
		}
		private XmlNode()
		{
			mChildren = new Dictionary<StringKeySequence, List<XmlNode>>();
			mValues = new Dictionary<StringKeySequence, List<string>>();
		}

		internal XmlNode([NotNull] XmlNode parent, StringKey identifier) : this()
		{
			if (parent == null)
			{
				throw new ArgumentNullException(nameof(parent));
			}

			Source = parent.Source;
			Identifier = identifier;
		}
		internal XmlNode([NotNull] XElement element) : this()
		{
			if (element == null)
			{
				throw new ArgumentNullException(nameof(element));
			}

			Source = new XmlNodeInfo(element);

			Identifier = element.Name.LocalName;
			mNamespace = GetNamespaceKey(element.Name);

			foreach (var attribute in element.Attributes())
			{
				var valueGroupKey = GetNameKey(attribute.Name);
				var valueGroupList = mValues.GetValueByKeyOrDefault(valueGroupKey);

				if (valueGroupList == null)
				{
					mValues.Add(valueGroupKey, valueGroupList = new List<string>());
				}

				valueGroupList.Add(attribute.Value.NormalizeNull());
			}

			foreach (var child in element.Elements())
			{
				var childGroupKey = GetNameKey(child.Name);

				if (!child.HasAttributes && !child.HasElements)
				{
					var childGroupList = mValues.GetValueByKeyOrDefault(childGroupKey);
					if (childGroupList == null)
					{
						mValues.Add(childGroupKey, childGroupList = new List<string>());
					}

					childGroupList.Add(child.Value.NormalizeNull());
					continue;
				}

				var nodeList = mChildren.GetValueByKeyOrDefault(childGroupKey);
				if (nodeList == null)
				{
					mChildren.Add(childGroupKey, nodeList = new List<XmlNode>());
				}

				nodeList.Add(new XmlNode(child));
			}

			mText = element.Value;
		}

		public static XmlNode Blank => mEmpty;

		public StringKey Identifier { get; }

		[NotNull]
		public XmlNodeInfo Source { get; }

		public bool HasChild(StringKey identifier, StringKey @namespace = default(StringKey))
		{
			return mChildren.ContainsKey(GetNameKey(identifier, @namespace));
		}
		public bool HasValue(StringKey identifier, StringKey @namespace = default(StringKey))
		{
			return mValues.ContainsKey(GetNameKey(identifier, @namespace));
		}

		[CanBeNull]
		public string Value()
		{
			return mText.NormalizeNull();
		}

		[CanBeNull]
		public string Value(StringKey identifier, StringKey @namespace = default(StringKey))
		{
			return Values(identifier, @namespace).FirstOrDefault();
		}

		[NotNull]
		public IReadOnlyDictionary<StringKey, string[]> Values(StringKey @namespace = default(StringKey))
		{
			if (@namespace.IsEmpty)
			{
				if (mNamespace.IsEmpty)
				{
					@namespace = new StringKey("<default>");
				}
				else
				{
					@namespace = mNamespace;
				}
			}

			return new ReadOnlyDictionary<StringKey, string[]>(mValues.Where(x => x.Key.Segments[1] == @namespace).ToDictionary(x => x.Key.Segments[0], x => x.Value.ToArray()));
		}

		[NotNull]
		public IReadOnlyList<string> Values(StringKey identifier, StringKey @namespace)
		{
			return mValues.GetValueByKeyOrDefault(GetNameKey(identifier, @namespace)) ?? (IReadOnlyList<string>)new string[0];
		}

		[NotNull]
		public XmlNode Child(StringKey identifier, StringKey @namespace = default(StringKey))
		{
			return Children(identifier, @namespace).FirstOrDefault() ?? new XmlNode(this, identifier);
		}

		[NotNull]
		public IReadOnlyList<XmlNode> Children()
		{
			return mChildren.SelectMany(x => x.Value).ToArray();
		}

		[NotNull]
		public IReadOnlyList<XmlNode> Children(StringKey identifier, StringKey @namespace = default(StringKey))
		{
			return mChildren.GetValueByKeyOrDefault(GetNameKey(identifier, @namespace)) ?? (IReadOnlyList<XmlNode>)new XmlNode[0];
		}

		private StringKeySequence GetNameKey(StringKey name, StringKey @namespace = default(StringKey))
		{
			if (@namespace.IsEmpty)
			{
				if (mNamespace.IsEmpty)
				{
					@namespace = new StringKey("<default>");
				}
				else
				{
					@namespace = mNamespace;
				}
			}

			return new StringKeySequence(name, @namespace);
		}
		private StringKeySequence GetNameKey(XName name)
		{
			return new StringKeySequence(name.LocalName.AsKey(), GetNamespaceKey(name));
		}
		private StringKey GetNamespaceKey(XName name)
		{
			if (string.IsNullOrEmpty(name.NamespaceName))
			{
				if (mNamespace.IsEmpty)
				{
					return new StringKey("<default>");
				}

				return mNamespace;
			}
			return name.NamespaceName.AsKey();
		}
	}
}