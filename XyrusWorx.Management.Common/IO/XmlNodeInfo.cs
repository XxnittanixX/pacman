using System;
using System.Xml;
using JetBrains.Annotations;

namespace XyrusWorx.Management.IO
{
	[PublicAPI]
	public class XmlNodeInfo
	{
		internal XmlNodeInfo([NotNull] IXmlLineInfo info)
		{
			if (info == null)
			{
				throw new ArgumentNullException(nameof(info));
			}

			LineNumber = info.LineNumber;
			ColumnNumber = info.LinePosition;
		}

		public int LineNumber { get; }
		public int ColumnNumber { get; }
	}
}