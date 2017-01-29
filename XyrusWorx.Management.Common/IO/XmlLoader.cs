using System;
using System.IO;
using System.Xml;
using System.Xml.Linq;
using JetBrains.Annotations;
using XyrusWorx.Diagnostics;

namespace XyrusWorx.Management.IO
{
	[PublicAPI]
	public class XmlLoader
	{
		[NotNull]
		public XmlLoadResult Load([NotNull] TextReader reader, ILogWriter log = null)
		{
			if (reader == null)
			{
				throw new ArgumentNullException(nameof(reader));
			}

			try
			{
				var document = XDocument.Load(reader, LoadOptions.SetLineInfo);
				var rootNode = document.Root;

				if (rootNode == null)
				{
					var errorMessage = "No root node could be found in the provided input stream.";

					log?.WriteError(errorMessage);

					return new XmlLoadResult(new[]
					{
						Result.CreateError(errorMessage)
					});
				}

				return new XmlLoadResult(new XmlNode(rootNode));
			}
			catch (XmlException exception)
			{
				var errorMessage = $"{exception.Message}";

				log?.WriteError(errorMessage);

				return new XmlLoadResult(new[]
				{
					Result.CreateError(exception)
				});
			}
		}
	}
}