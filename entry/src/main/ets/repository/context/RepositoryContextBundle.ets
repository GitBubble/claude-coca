import {
  RepositoryContextBundle,
  RepositoryContextFile,
  SelectedFileRange
} from '../domain/RepositoryTypes';

export function createRepositoryContextBundle(files: RepositoryContextFile[], createdAt: number): RepositoryContextBundle {
  return {
    id: `repo-context-${createdAt}`,
    createdAt,
    files: files.map((file: RepositoryContextFile) => normalizeContextFile(file))
  };
}

export function estimateContextBytes(bundle: RepositoryContextBundle): number {
  return bundle.files.reduce((total: number, file: RepositoryContextFile) => {
    return total + file.content.length;
  }, 0);
}

function normalizeContextFile(file: RepositoryContextFile): RepositoryContextFile {
  return {
    provider: file.provider,
    repository: file.repository,
    branch: file.branch,
    path: file.path,
    commitSha: file.commitSha,
    language: file.language,
    content: file.content,
    contentHash: file.contentHash,
    selectedRanges: normalizeSelectedRanges(file.selectedRanges)
  };
}

function normalizeSelectedRanges(ranges: SelectedFileRange[]): SelectedFileRange[] {
  return ranges
    .filter((range: SelectedFileRange) => range.startLine > 0 && range.endLine >= range.startLine)
    .sort((left: SelectedFileRange, right: SelectedFileRange) => left.startLine - right.startLine);
}
