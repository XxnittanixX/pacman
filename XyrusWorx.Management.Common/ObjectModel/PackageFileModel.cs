using System;
using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageFileModel
	{
		private readonly string mPattern;
		private readonly PackageFolder mTargetFolder;

		public PackageFileModel([NotNull] string pattern, [NotNull] PackageFolder targetFolder)
		{
			if (pattern.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(pattern));
			}

			if (targetFolder == null)
			{
				throw new ArgumentNullException(nameof(targetFolder));
			}

			mPattern = pattern;
			mTargetFolder = targetFolder;
		}

		[NotNull]
		public string Pattern => mPattern;

		[NotNull]
		public PackageFolder TargetFolder => mTargetFolder;
	}
}