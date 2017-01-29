using System.IO;
using JetBrains.Annotations;
using XyrusWorx.Diagnostics;
using XyrusWorx.Management.IO;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public abstract class XmlProjectDefinition : ProjectDefinition<XmlNode>
	{
		private readonly XmlLoader mLoader;

		protected XmlProjectDefinition([NotNull] string projectFilePath) : base(projectFilePath)
		{
			mLoader = new XmlLoader();
		}

		protected sealed override Result<XmlNode> LoadSourceModel(ILogWriter log)
		{
			using (var reader = new StreamReader(File.Open(ProjectFile.FullName, FileMode.Open, FileAccess.Read, FileShare.Read)))
			{
				var readResult = mLoader.Load(reader, log);
				if (readResult.HasError)
				{
					return Result.CreateError<Result<XmlNode>>(readResult.ErrorDescription);
				}

				return new Result<XmlNode>(readResult.Data);
			}
		}
	}
}