using System;
using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageContentModel
	{
		private readonly string mPattern;
		private readonly string mTargetFolder;

		public PackageContentModel([NotNull] string pattern, [NotNull] string targetFolder)
		{
			if (pattern.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(pattern));
			}

			if (targetFolder.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(targetFolder));
			}

			mPattern = pattern;
			mTargetFolder = targetFolder;
		}

		[NotNull]
		public string Pattern => mPattern;

		[NotNull]
		public string TargetFolder => mTargetFolder;
	}
}