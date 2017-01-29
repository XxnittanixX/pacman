using System.Collections.Generic;
using JetBrains.Annotations;
using XyrusWorx.Collections;

namespace XyrusWorx.Management.IO
{
	[PublicAPI]
	public class XmlLoadResult : MultiResult
	{
		internal XmlLoadResult(IEnumerable<IResult> errors)
		{
			Results.AddRange(errors);
		}
		internal XmlLoadResult(XmlNode node)
		{
			Data = node;
		}

		public XmlNode Data { get; }
	}
}